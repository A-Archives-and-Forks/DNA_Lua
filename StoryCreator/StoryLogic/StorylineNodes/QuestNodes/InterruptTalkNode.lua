local InterruptTalkNode = Class("StoryCreator.StoryLogic.StorylineNodes.BaseQuestNode")

function InterruptTalkNode:Init()
  self.FirstDialogueId = 0
end

function InterruptTalkNode:Execute()
  DebugPrint("InterruptTalkNode:Execute", self.FirstDialogueId)
  local TS = TalkSubsystem()
  if not TS then
    DebugPrint("获取TalkSubsystem失败")
    return
  end
  TalkSubsystem():ForceInterruptTalkTaskData(function(TaskData)
    return TaskData.FirstDialogueId == self.FirstDialogueId
  end)
end

return InterruptTalkNode
