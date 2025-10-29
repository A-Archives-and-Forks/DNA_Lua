local M = {}
local DefaultPath = "Blueprint'/Game/AssetDesign/Camera/CameraShake/Story/"

function M:CreateNode(Flow, TalkTask, Params)
  local ShakeClassPath = Params.Path
  if not ShakeClassPath then
    local FileName = Params.FileName
    if not FileName then
      local Message = string.format("CameraShake脚本执行失败: 未填写Path或FileName, DialogueId: %d", Flow.DialogueId)
      UStoryLogUtils.PrintToFeiShu(GWorld.GameInstance, "对话运行时出错", Message)
      return
    end
    ShakeClassPath = DefaultPath .. FileName .. "." .. FileName .. "'"
  end
  local TalkContext = GWorld.GameInstance:GetTalkContext()
  local ShakeClass = LoadClass(ShakeClassPath)
  if nil == ShakeClass then
    local Message = string.format("CameraShake create failed: ShakeClass not found, ShakeClassPath: %d, DialogueId: %d", ShakeClassPath, Flow.DialogueId)
    UStoryLogUtils.PrintToFeiShu(GWorld.GameInstance, "对话运行时出错", Message)
    return
  end
  local PlayerCameraManager = UE4.UGameplayStatics.GetPlayerCameraManager(GWorld.GameInstance, 0)
  if nil == PlayerCameraManager then
    local Message = string.format("CameraShake create failed: PlayerCameraManager not found, DialogueId: %d", Flow.DialogueId)
    UStoryLogUtils.PrintToFeiShu(GWorld.GameInstance, "对话运行时出错", Message)
    return
  end
  local CameraShakeNode = Flow:CreateNode(UEFNode_Delegate)
  CameraShakeNode.DebugLog = string.format("CameraShake ShakeClassPath: %s", ShakeClassPath)
  local HasCallback = false
  local CameraShakeInst
  CameraShakeNode.OnStart:Add(CameraShakeNode, function(Node)
    local function FinishCallback()
      if HasCallback then
        return
      end
      if not IsValid(Node) then
        return
      end
      TalkContext.TalkTimerManager:ClearTimer(Node)
      HasCallback = true
      Node:Finish({
        Node.FinishPin
      })
    end
    
    CameraShakeInst = PlayerCameraManager:StartCameraShake(ShakeClass)
    TalkContext.TalkTimerManager:AddTimer(Node, CameraShakeInst.OscillationDuration, false, nil, nil, FinishCallback)
  end)
  CameraShakeNode.OnSkip:Add(CameraShakeNode, function(Node)
    TalkContext.TalkTimerManager:ClearTimer(Node)
    PlayerCameraManager:StopCameraShake(CameraShakeInst)
    HasCallback = true
    Node:Finish({
      Node.FinishPin
    })
  end)
  CameraShakeNode.OnPause:Add(CameraShakeNode, function(Node)
    TalkTask:PauseCamera(true)
    TalkContext.TalkTimerManager:PauseTimer(Node)
  end)
  CameraShakeNode.OnResume:Add(CameraShakeNode, function(Node)
    TalkTask:PauseCamera(false)
    TalkContext.TalkTimerManager:UnPauseTimer(Node)
  end)
  return CameraShakeNode
end

return M
