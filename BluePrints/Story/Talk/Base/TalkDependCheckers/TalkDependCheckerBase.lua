require("UnLua")
local TalkDependCheckerBase = Class()

function TalkDependCheckerBase:Init()
  self.bEnabled = false
end

function TalkDependCheckerBase:Enable(Task, TaskData)
  if not self:IsSelfValid() then
    return
  end
  self.bEnabled = true
  self:OnEnabled(Task, TaskData)
end

function TalkDependCheckerBase:Disable(Task)
  if not self:IsSelfValid() then
    return
  end
  self.bEnabled = false
  self:OnDisabled(Task)
end

function TalkDependCheckerBase:IsSelfHasEnabled()
  return self.bEnabled
end

function TalkDependCheckerBase:OnEnabled()
end

function TalkDependCheckerBase:OnDisabled()
end

function TalkDependCheckerBase:IsCheckerCompletedInternal(Task, TaskData)
  DebugPrint("@@@ error 请实现此TalkChecker IsCheckerCompletedInternal")
end

function TalkDependCheckerBase:Clear()
  DebugPrint("@@@ error 请实现此TalkChecker Clear")
end

function TalkDependCheckerBase:IsCheckerCompleted(Task, TaskData)
  if not self:IsSelfValid() then
    return true
  end
  return self:IsCheckerCompletedInternal(Task, TaskData)
end

function TalkDependCheckerBase:BindCompletedCallback(Callback)
  self.OnCompletedDelegate = Callback
end

function TalkDependCheckerBase:IsSelfActive()
  return self.bEnabled
end

function TalkDependCheckerBase:IsSelfValid()
  DebugPrint("@@@ TalkChecker IsSelfValid")
  return true
end

function TalkDependCheckerBase:IsSelfAutoEnabled()
  return false
end

return TalkDependCheckerBase
