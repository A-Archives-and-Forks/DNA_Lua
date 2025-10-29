require("UnLua")
local TalkActorAvailableChecker_C = Class("BluePrints.Story.Talk.Base.TalkDependCheckers.TalkDependCheckerBase")

function TalkActorAvailableChecker_C:Init()
  TalkActorAvailableChecker_C.Super.Init(self)
  self.WorkingTasks = {}
  self.ListenNpcIds = {}
  self.RecordGetNpcInfoAsyncCallbacks = {}
end

function TalkActorAvailableChecker_C:OnEnabled(Task, TaskData)
  do return end
  DebugPrint("@@@ 启用TalkActorAvailableChecker_C", Task)
  self:ListeningEvent(Task, TaskData)
end

function TalkActorAvailableChecker_C:OnDisabled(Task)
  do return end
  DebugPrint("@@@ 关闭TalkActorAvailableChecker_C", Task)
  self:UnlisteningEvent(Task)
end

function TalkActorAvailableChecker_C:Clear()
  self.WorkingTasks = {}
  for _, Task in pairs(self.WorkingTasks) do
    self:UnlisteningEvent(Task)
  end
end

function TalkActorAvailableChecker_C:IsCheckerCompletedInternal(Task, TaskData)
  do return true end
  return not self:CheckAnyTalkActorInAsyncCreate(TaskData.CreateTalkActors)
end

function TalkActorAvailableChecker_C:CheckAnyTalkActorInAsyncCreate(TalkActorInfos)
  local GameState = UE4.URuntimeCommonFunctionLibrary.GetCurrentGameState(GWorld.GameInstance)
  local bRes = false
  for _, Info in pairs(TalkActorInfos) do
    local NpcId = Info.TalkActorId
    local NpcType = Info.TalkActorType
    if "Npc" == NpcType then
      local bAsync = GameState:IsNpcInAsyncProcess(NpcId)
      bRes = bRes or bAsync
      if bAsync then
        DebugPrint("TalkActorAvailableChecker_C:CheckAnyTalkActorInAsyncCreate  Npc处于异步流程中(序列化/异步创建等)", NpcId)
      end
    end
  end
  return bRes
end

function TalkActorAvailableChecker_C:TryFireCompleteDelegate(Task, TaskData)
  if self:IsCheckerCompleted(Task, TaskData) then
    self:UnlisteningEvent(Task)
    self:OnCompletedDelegate()
  end
end

function TalkActorAvailableChecker_C:ListeningEvent(Task, TaskData)
  DebugPrint("@@@ 监听TalkActor是否是可用的 ", Task)
  self.WorkingTasks[Task] = Task
  for _, Info in pairs(TaskData.CreateTalkActors) do
    local NpcId = Info.TalkActorId
    local NpcType = Info.TalkActorType
    if "Npc" == NpcType then
      table.insert(self.ListenNpcIds, NpcId)
      self:ListenNpc(Task, NpcId, function()
        self:UnlistenNpc(Task, NpcId)
        self:TryFireCompleteDelegate(Task, TaskData)
      end)
    end
  end
end

function TalkActorAvailableChecker_C:UnlisteningEvent(Task)
  local TaskData = TalkSubsystem():GetTaskDataFromTalkTask(Task)
  DebugPrint("@@@ 取消监听TalkActor是否是可用的", Task, TaskData)
  self.WorkingTasks[Task] = nil
  local GameState = UE4.URuntimeCommonFunctionLibrary.GetCurrentGameState(GWorld.GameInstance)
  for _, Info in pairs(TaskData.CreateTalkActors) do
    local NpcId = Info.TalkActorId
    GameState:RemoveNpcInfoAsyncCallback(NpcId)
  end
end

function TalkActorAvailableChecker_C:ListenNpc(Task, NpcId, LambdaCallback)
  local GameState = UE4.URuntimeCommonFunctionLibrary.GetCurrentGameState(GWorld.GameInstance)
  
  local function GetNpcInfoAsyncCB(Npc)
    LambdaCallback()
  end
  
  self.RecordGetNpcInfoAsyncCallbacks[Task] = self.RecordGetNpcInfoAsyncCallbacks[Task] or {}
  self.RecordGetNpcInfoAsyncCallbacks[Task][NpcId] = self.RecordGetNpcInfoAsyncCallbacks[Task][NpcId] or {}
  self.RecordGetNpcInfoAsyncCallbacks[Task][NpcId][GetNpcInfoAsyncCB] = GetNpcInfoAsyncCB
  GameState:GetNpcInfoAsync(NpcId, GetNpcInfoAsyncCB)
end

function TalkActorAvailableChecker_C:UnlistenNpc(Task, NpcId)
  local GameState = UE4.URuntimeCommonFunctionLibrary.GetCurrentGameState(GWorld.GameInstance)
  local TaskCBs = self.RecordGetNpcInfoAsyncCallbacks[Task] or {}
  for _, NpcIdCBs in pairs(TaskCBs) do
    for _, CBs in pairs(NpcIdCBs[NpcId] or {}) do
      for _, CB in pairs(CBs or {}) do
        GameState:RemoveGetNpcInfoAsyncDelegate(NpcId, CB)
      end
    end
  end
end

return TalkActorAvailableChecker_C
