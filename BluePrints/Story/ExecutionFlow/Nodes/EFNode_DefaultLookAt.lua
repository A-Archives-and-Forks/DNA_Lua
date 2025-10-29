local M = {}

function M:CreateNode(Flow, TalkTask, Params)
  local SpeakActorId = Params.SpeakActorId
  local LookAtType = Params.LookAtType
  local TalkContext = GWorld.GameInstance:GetTalkContext()
  if not IsValid(TalkContext) then
    local Message = string.format("DefaultLookAt create failed: TalkContext not found, DialogueId: %d", Flow.DialogueId)
    UStoryLogUtils.PrintToFeiShu(GWorld.GameInstance, "对话运行时出错", Message)
    return
  end
  local DefaultLookAtNode = Flow:CreateNode(UEFNode_Delegate)
  DefaultLookAtNode.DebugLog = string.format("DefaultLookAt SpeakActorId: %s, LookAtType: %s", SpeakActorId, LookAtType)
  DefaultLookAtNode.OnStart:Add(DefaultLookAtNode, function(Node)
    TalkContext.TalkActionManager:DefaultLookAt(TalkContext, TalkTask, TalkTask.TalkTaskData, SpeakActorId, LookAtType)
    Node:Finish({
      Node.FinishPin
    })
  end)
  return DefaultLookAtNode
end

return M
