local OpenSytstemUINode = Class("StoryCreator.StoryLogic.StorylineNodes.BaseAsynQuestNode")

function OpenSytstemUINode:Init()
  self.Delay = 0.5
  self.UIName = ""
end

function OpenSytstemUINode:Execute(Callback)
  EventManager:AddEvent(EventID.UnLoadUI, self, self.OnUIClose)
  self:OpenUI(self.UIName)
  self.Callback = Callback
end

function OpenSytstemUINode:Clear()
  if self.ExecuteTimer then
    GWorld.GameInstance:RemoveTimer(self.ExecuteTimer)
    self.ExecuteTimer = nil
  end
end

function OpenSytstemUINode:OnUIClose(UIName)
  if UIName == self.UIName then
    self:ExecuteNext()
  end
end

function OpenSytstemUINode:ExecuteNext()
  EventManager:RemoveEvent(EventID.UnLoadUI, self)
  self.Callback()
end

function OpenSytstemUINode:OpenUI(UIName, ...)
  local GameInstance = GWorld.GameInstance
  local UIManager = GameInstance:GetGameUIManager()
  local SystemUIConfig = DataMgr.SystemUI[UIName]
  if nil ~= SystemUIConfig then
    return UIManager:LoadUINew(UIName, ...)
  end
  local UIConfig = UIConst.AllUIConfig[UIName]
  if nil == UIConfig then
    ScreenPrint(string.format("OpenSytstemUINode：打开界面节点出错，没有找到相关UI信息,请检查节点填入的UIName,UI名字为%s", UIName))
    DebugPrint("========================================================================OpenSytstemUINode: Not Find UIName In SystemUI or AllUIConfig, UIName Is : %s ", UIName)
    local Message = "OpenSytstemUINode：打开界面节点出错，没有找到相关UI信息,请检查节点填入的UIName,UI名字为" .. UIName
    UStoryLogUtils.PrintToFeiShu(GWorld.GameInstance, "OpenSytstemUINode节点出错，没有找到相关UI信息", Message)
    EventManager:RemoveEvent(EventID.UnLoadUI, self)
    return
  end
  return UIManager:LoadUI(UIConfig.resource, UIName, UIConfig.zorder)
end

return OpenSytstemUINode
