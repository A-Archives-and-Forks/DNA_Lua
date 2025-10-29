local M = {}

function M:CreateNode(Flow, TalkTask, Params)
  local MaterialInstance = Params.MaterailInstance
  local TalkContext = GWorld.GameInstance:GetTalkContext()
  if not IsValid(TalkContext) then
    local Message = string.format("PostProcess create failed: TalkContext not found, DialogueId: %d", Flow.DialogueId)
    UStoryLogUtils.PrintToFeiShu(GWorld.GameInstance, "对话运行时出错", Message)
    return
  end
  local PostProcessNode = Flow:CreateNode(UEFNode_Delegate)
  PostProcessNode.DebugLog = string.format("PostProcess MaterialInstance: %s", MaterialInstance)
  PostProcessNode.OnStart:Add(PostProcessNode, function(Node)
    TalkContext.TalkCameraManager:SetPostProcess(MaterialInstance)
    Node:Finish({
      Node.FinishPin
    })
  end)
  return PostProcessNode
end

return M
