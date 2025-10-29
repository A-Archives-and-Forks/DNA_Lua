require("UnLua")
local EffectResults = require("BluePrints.Combat.BattleLogic.EffectResults")
local CharacterDataStruct = require("BluePrints.Combat.Components.CharacterDataStruct")
local EMCache = require("EMCache.EMCache")
local BP_Battle_C = Class("BluePrints.Common.TimerMgr")
BP_Battle_C._components = {
  "BluePrints.Combat.BattleLogic.AttrLogic",
  "BluePrints.Combat.BattleLogic.BattleEventLogic",
  "BluePrints.Combat.BattleLogic.BattleGMLogic",
  "BluePrints.Combat.BattleLogic.BuffLogic",
  "BluePrints.Combat.BattleLogic.CampLogic",
  "BluePrints.Combat.BattleLogic.CharacterLogic",
  "BluePrints.Combat.BattleLogic.CreatureLogic",
  "BluePrints.Combat.BattleLogic.DamageLogic",
  "BluePrints.Combat.BattleLogic.PositionLogic",
  "BluePrints.Combat.BattleLogic.SeekEnemyLogic",
  "BluePrints.Combat.BattleLogic.SkillRawEffects",
  "BluePrints.Combat.BattleLogic.TargetFilterLogic",
  "BluePrints.Combat.BattleLogic.DeadLogic",
  "BluePrints.Combat.BattleLogic.ConditionLogic",
  "BluePrints.Combat.BattleLogic.ToughnessLogic",
  "BluePrints.Combat.BattleLogic.BattlePlayMgr",
  "BluePrints.Combat.BattleLogic.LaserLogic",
  "BluePrints.Combat.Components.SkillCreaturePool",
  "BluePrints.Combat.BattleLogic.DanmakuLogic"
}

function BP_Battle_C:CanExecute()
  local GameState = UE4.UGameplayStatics.GetGameState(self)
  if not GameState:CheckGameModeStateNotEnd() then
    return false
  end
  if IsStandAlone(self) then
    return true
  end
  if IsDedicatedServer(self) then
    return true
  end
  if self.ClientExec then
    return true
  end
  return false
end

function BP_Battle_C:ReceiveBeginPlay()
  print(_G.LogTag, "BP_Battle_C ReceiveBeginPlay")
  GWorld.Battle = self
  self.Overridden.ReceiveBeginPlay(self)
  rawset(self, "BattleEvent", self.BattleEvent)
  self.BattleEventSignatures:Clear()
  self.Results = EffectResults.Results()
  self.Result = EffectResults.Result()
  self.CreatureSrouceMap = {}
  self.CreatureDelayHandles = {}
  self.HpLinkBuffDic = {}
  local GameState = UE4.UGameplayStatics.GetGameState(self)
  GameState.Battle = self
  self:OnCreated()
  EventManager:AddEvent(EventID.TalkPauseGame, self, self.ClearAllDanmaku)
end

function BP_Battle_C:OnCreated()
  assert(Battle(self))
  if IsAuthority(self) then
    self:TriggerGameModeBattleInit()
  end
  print(_G.LogTag, "FireEvent OnBattleReady")
  EventManager:FireEvent(EventID.OnBattleReady, self)
end

function BP_Battle_C:GetClientOnlyFunction_Lua()
  return {
    "ExecuteClientPassiveFunction",
    "PlayUIAnim",
    "AimDiffusion",
    "BeginAccumulate",
    "CameraShake",
    "AdditionalHitFX"
  }
end

function BP_Battle_C:GetClientPredictFunction_Lua()
  return {"PlayFX", "PlaySE"}
end

function BP_Battle_C:GetServerClientBothFunction_Lua()
  return {
    "AddCameraSpeed",
    "AddCharFallSpeed",
    "HitStop",
    "ExecuteClientSkillLogicFunction",
    "ChangeModel"
  }
end

function BP_Battle_C:GetServerClientBothNetMulticastFunction_Lua()
  return {
    "CreateSkillCreature",
    "CreateRayCreature",
    "RemoveRayCreature",
    "RemoveSkillCreature",
    "StartLoopShoot",
    "EndLoopShoot",
    "UpdateLoopShoot",
    "StartHeavyCharge",
    "ExecuteHeavyEffect",
    "SaveLoc",
    "OverrideCharVelocity",
    "CallBackSkillCreature",
    "ClearHitTargets",
    "ReplaceBulletFXID",
    "RemoveDanmaku"
  }
end

function BP_Battle_C:GetLuaOverrideFunction_Lua()
  return {}
end

function BP_Battle_C:TriggerGameModeBattleInit()
  if not IsAuthority(self) then
    return
  end
  UE4.UGameplayStatics.GetGameMode(self):TryTriggerOnPrepare("BattleInit")
end

function BP_Battle_C:FlushEffectResult_Lua()
  if self.Result and not self.Result.IsEmpty then
    self.Results:Add(self.Result)
    self.Result = EffectResults.Result()
  end
  if self.Results and not self.Results.IsEmpty and self.Results.ToEffectStruct then
    local EffectStruct = self.Results:ToEffectStruct()
    self:AddEffectStruct(EffectStruct)
    self.Results = EffectResults.Results()
  end
end

function BP_Battle_C:DelayCreateSkillCreature()
  local Battle = Battle(self)
  for i, v in pairs(self.CreatureSrouceMap) do
    local function CreateSkillCreatureDelay(self)
      if not UE4.UKismetSystemLibrary.IsValid(v.Source) then
        return
      end
      local BornLocationData = v.BornLocationData
      if self.BornLocation and BornLocationData and 1 ~= BornLocationData.Index then
        v.BornLocation = FVector(self.BornLocation.X, self.BornLocation.Y + BornLocationData.YOffset, self.BornLocation.Z + BornLocationData.ZOffset)
      end
      local Creature = Battle:CreateSkillCreature(v, true)
      if BornLocationData and 1 == BornLocationData.Index then
        self.BornLocation = Creature.BornLocation
      elseif not BornLocationData then
        self.BornLocation = nil
      end
    end
    
    local Interval = 0.01 * (i - 1)
    if Interval > 0 then
      local Handle = UE4.UKismetSystemLibrary.K2_SetTimerDelegate({self, CreateSkillCreatureDelay}, Interval, false)
      table.insert(self.CreatureDelayHandles, Handle)
    else
      CreateSkillCreatureDelay(self)
    end
  end
  self.CreatureSrouceMap = {}
end

function BP_Battle_C:ReceiveEndPlay()
  if self.Components then
    for _, Module in pairs(self.Components) do
      Module:Destroy(self)
    end
  end
  for i, v in pairs(self.CreatureDelayHandles) do
    UE4.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self, v)
  end
  EventManager:RemoveEvent(EventID.TalkPauseGame, self)
  GWorld.Battle = nil
end

function BP_Battle_C:ToTable(SourceCharacter)
  local CharStruct = New(CharacterDataStruct)
  CharStruct.Eid = SourceCharacter.Eid
  CharStruct.Location = {
    SourceCharacter:K2_GetActorLocation().X,
    SourceCharacter:K2_GetActorLocation().Y,
    SourceCharacter:K2_GetActorLocation().Z
  }
  CharStruct.CurrentSkillId = SourceCharacter.CurrentSkillId
  if SourceCharacter and SourceCharacter.GetFireSkill then
    CharStruct.FireSkillId = SourceCharacter:GetSkillByType(UE.ESkillType.Shooting)
  end
  if SourceCharacter and SourceCharacter.GetCurrentWeapon and SourceCharacter:GetCurrentWeapon() then
    CharStruct.CurrentWeapon = SourceCharacter:GetCurrentWeapon().WeaponId
  end
  return CharStruct
end

function BP_Battle_C:ToStruct(CharStruct)
  function CharStruct.K2_GetActorLocation()
    return FVector(CharStruct.Location[1], CharStruct.Location[2], CharStruct.Location[3])
  end
  
  function CharStruct.GetFireSkill()
    return CharStruct.FireSkillId
  end
  
  function CharStruct.GetCurrentWeapon()
    if not Battle(self):GetEntity(CharStruct.Eid) then
      return nil
    end
    local Character = Battle(self):GetEntity(CharStruct.Eid)
    if not Character.Weapons then
      return
    end
    return Character.Weapons[CharStruct.CurrentWeapon]
  end
  
  return CharStruct
end

function BP_Battle_C:ShowBattleErrorLua(Text)
  self:ShowBattleError(Text, true)
end

function BP_Battle_C:StandardShowBattleErrorLua(Type, Title, Content, bCallFromCpp)
  Content = Content or ""
  if nil == Type then
    DebugPrint(ErrorTag, "StandardShowBattleErrorLua:参数Type为nil")
    return
  end
  local TypeString
  local Success, Result = pcall(function()
    return UE.EShowBattleErrorType:GetNameStringByValue(Type)
  end)
  if not (Success and Result) or "" == Result then
    DebugPrint(ErrorTag, "StandardShowBattleErrorLua:参数Type不是有效的EShowBattleErrorType枚举值")
    return
  end
  TypeString = Result
  if nil == Title then
    DebugPrint(ErrorTag, "StandardShowBattleErrorLua:参数Title为nil")
    Title = "nil"
  elseif type(Title) ~= "string" and type(Title) ~= "number" then
    Title = tostring(Title)
  end
  if nil == Content then
    DebugPrint(ErrorTag, "StandardShowBattleErrorLua:参数Content为nil")
    Content = "nil"
  elseif type(Content) ~= "string" and type(Content) ~= "number" then
    Content = tostring(Content)
  end
  local bDistribution = UE4.URuntimeCommonFunctionLibrary.IsDistribution()
  if bDistribution then
    return
  end
  local Space = "=========================================================\n"
  local Ct = "" ~= Content and {
    Space,
    "【错误大类】: ",
    TypeString,
    "\n",
    "【Title】: ",
    Title,
    "\n",
    "【Content】: ",
    Content,
    [[


]]
  } or {
    Space,
    "【错误大类】: ",
    TypeString,
    "\n",
    "【Title】: ",
    Title,
    [[


]]
  }
  local Ret
  self:FillBattleLog(Ct)
  if not bCallFromCpp then
    table.insert(Ct, Space)
    table.insert(Ct, [[
Traceback:
	]])
    table.insert(Ct, debug.traceback())
    table.insert(Ct, "\n")
  end
  Ret = table.concat(Ct)
  if UE4.URuntimeCommonFunctionLibrary.IsPlayInEditor(self) then
    ScreenPrint("战斗报错(StandardShowBattleError):\n" .. Ret)
  end
  if not GWorld.ErrorDict then
    GWorld.ErrorDict = {}
  end
  local ErrorDictContent = TypeString .. Title
  if "" ~= ErrorDictContent and GWorld.ErrorDict[ErrorDictContent] then
    return
  end
  GWorld.ErrorDict[ErrorDictContent] = true
  local TraceType = {
    first = GText("战斗报错"),
    second = TypeString,
    third = Title
  }
  local DescribeInfo = {
    title = GText("详细信息"),
    trace_content = Ret
  }
  local Avatar = GWorld:GetAvatar()
  if Avatar then
    Avatar:SendToFeishuForBattle(Ret, "战斗报错" .. TypeString)
    Avatar:SendTraceToQaWeb(TraceType, DescribeInfo)
    return
  end
  local DSEntity = GWorld:GetDSEntity()
  if DSEntity then
    DSEntity:SendToFeishuForBattle(Ret, "战斗报错" .. TypeString)
    DSEntity:SendTraceToQaWeb(TraceType, DescribeInfo)
    return
  end
end

function BP_Battle_C:FillBattleCharacterLog(Ct, Player)
  if not Player then
    return
  end
  local CurrentRoleId = Player.CurrentRoleId
  table.insert(Ct, "使用角色ID:")
  table.insert(Ct, tostring(CurrentRoleId))
  if DataMgr.BattleChar[CurrentRoleId] then
    local RoleName = GText(DataMgr.BattleChar[CurrentRoleId].CharName)
    table.insert(Ct, "(")
    table.insert(Ct, tostring(RoleName))
    table.insert(Ct, ")")
  end
  if Player.MeleeWeapon then
    local WeaponId = Player.MeleeWeapon.WeaponId
    table.insert(Ct, ",近战武器ID:")
    table.insert(Ct, tostring(Player.MeleeWeapon.WeaponId))
    local WeaponInfo = DataMgr.Weapon[WeaponId]
    if WeaponInfo then
      local WeaponName = WeaponInfo.WeaponName
      if DataMgr.TextMap[WeaponName] then
        WeaponName = GText(WeaponName)
      end
      if WeaponName then
        table.insert(Ct, "(")
        table.insert(Ct, WeaponName)
        table.insert(Ct, ")")
      end
    end
  end
  if Player.RangedWeapon then
    local WeaponId = Player.RangedWeapon.WeaponId
    table.insert(Ct, ",远程武器ID:")
    table.insert(Ct, tostring(Player.RangedWeapon.WeaponId))
    local WeaponInfo = DataMgr.Weapon[WeaponId]
    if WeaponInfo then
      local WeaponName = WeaponInfo.WeaponName
      if DataMgr.TextMap[WeaponName] then
        WeaponName = GText(WeaponName)
      end
      if WeaponName then
        table.insert(Ct, "(")
        table.insert(Ct, WeaponName)
        table.insert(Ct, ")")
      end
    end
  end
  if Player:IsPlayer() then
    local Flag = false
    local PhantomTeammate = Player:GetPhantomTeammates()
    for _, Target in pairs(PhantomTeammate) do
      if Target ~= Player then
        if not Flag then
          table.insert(Ct, "\n正在使用的魅影信息:")
          Flag = true
        end
        table.insert(Ct, [[

	]])
        self:FillBattleCharacterLog(Ct, Target)
      end
    end
  end
end

function BP_Battle_C:FillBattleLog(Ct)
  local Avatar = GWorld:GetAvatar()
  table.insert(Ct, "环境:")
  if IsClient(self) then
    table.insert(Ct, "联机客户端")
  elseif IsDedicatedServer(self) then
    table.insert(Ct, "联机服务端")
  elseif Avatar and Avatar:IsInHardBoss() then
    table.insert(Ct, "梦魇残声")
    if Avatar.HardBossInfo then
      table.insert(Ct, ":编号[")
      local HardBossId = Avatar.HardBossInfo.HardBossId
      table.insert(Ct, HardBossId)
      table.insert(Ct, "]")
      local Context
      if DataMgr.HardBossMain[HardBossId] then
        local HardBossName = DataMgr.HardBossMain[HardBossId].HardBossName
        if DataMgr.TextMap[HardBossName] then
          Context = GText(HardBossName)
        end
      end
      if Context then
        table.insert(Ct, "[")
        table.insert(Ct, Context)
        table.insert(Ct, "]")
      end
      local DifficultyId = Avatar.HardBossInfo.DifficultyId
      local DifficultyLevel
      if DifficultyId and DataMgr.HardBossDifficulty[DifficultyId] then
        DifficultyLevel = DataMgr.HardBossDifficulty[DifficultyId].DifficultyLevel
      end
      table.insert(Ct, ":难度等级[")
      table.insert(Ct, DifficultyLevel)
      table.insert(Ct, "]")
    end
  elseif Avatar and Avatar.CurrentOnlineType and -1 ~= Avatar.CurrentOnlineType then
    table.insert(Ct, "区域联机")
  else
    table.insert(Ct, "单机")
  end
  local PlatformName
  if UE4.URuntimeCommonFunctionLibrary.IsPlayInEditor(self) then
    PlatformName = "编辑器"
  else
    PlatformName = UGameplayStatics.GetPlatformName()
  end
  table.insert(Ct, "  平台:" .. tostring(PlatformName))
  table.insert(Ct, "\n")
  local GameMode = UE4.UGameplayStatics.GetGameMode(self)
  if IsDedicatedServer(self) then
    local AllPlayer = GameMode:GetAllPlayer()
    for i, Player in pairs(AllPlayer) do
      table.insert(Ct, "[")
      table.insert(Ct, i)
      table.insert(Ct, "]")
      self:FillBattleCharacterLog(Ct, Player)
      table.insert(Ct, "\n")
    end
  else
    local Player = UE4.UGameplayStatics.GetPlayerCharacter(self, 0)
    local CurrentRoleId
    if Player then
      CurrentRoleId = Player.CurrentRoleId
    end
    self:FillBattleCharacterLog(Ct, Player)
    table.insert(Ct, "\n")
  end
  local GameState = UE.UGameplayStatics.GetGameState(self.Player)
  if IsValid(GameState) then
    local DungeonId = GameState.DungeonId
    if DungeonId and DungeonId > 0 then
      table.insert(Ct, "副本ID:")
      table.insert(Ct, tostring(DungeonId))
      local DungeonInfo = DataMgr.Dungeon[DungeonId]
      if DungeonInfo then
        local DungeonName = DungeonInfo.DungeonName
        if DataMgr.TextMap[DungeonName] then
          DungeonName = GText(DungeonName)
        end
        table.insert(Ct, "(")
        table.insert(Ct, tostring(DungeonName))
        table.insert(Ct, ")")
      end
      table.insert(Ct, "\n")
    end
  end
  if IsValid(GameMode) and GameMode:IsInRegion() and Avatar then
    local RegionId = Avatar:GetCurrentRegionId()
    table.insert(Ct, "子区域ID:")
    table.insert(Ct, tostring(RegionId))
    local RegionInfo = DataMgr.SubRegion[RegionId]
    if RegionInfo then
      local RegionName = RegionInfo.SubRegionName
      if DataMgr.TextMap[RegionName] then
        RegionName = GText(RegionName)
      end
      table.insert(Ct, "(")
      table.insert(Ct, tostring(RegionName))
      table.insert(Ct, ")")
    end
    table.insert(Ct, "\n")
  end
  table.insert(Ct, Space)
end

function BP_Battle_C:ShowBattleError(Text, HideTraceback)
  local bDistribution = UE4.URuntimeCommonFunctionLibrary.IsDistribution()
  local bEnableShippingLog = UE4.URuntimeCommonFunctionLibrary.EnableLogInShipping()
  if bDistribution and not bEnableShippingLog then
    return
  end
  local Space = "=========================================================\n"
  local Ct = {
    Space,
    "报错文本:\n\t",
    tostring(Text),
    "\n"
  }
  local Ret
  if not HideTraceback then
    table.insert(Ct, Space)
    table.insert(Ct, [[
Traceback:
	]])
    table.insert(Ct, debug.traceback())
    table.insert(Ct, "\n")
  end
  table.insert(Ct, Space)
  self:FillBattleLog(Ct)
  Ret = table.concat(Ct)
  if UE4.URuntimeCommonFunctionLibrary.IsPlayInEditor(self) then
    ScreenPrint("战斗报错:\n" .. Ret)
  end
  if not GWorld.ErrorDict then
    GWorld.ErrorDict = {}
  end
  if GWorld.ErrorDict[Text] then
    return
  end
  GWorld.ErrorDict[Text] = true
  local TraceType = {
    first = "战斗报错",
    second = "旧版ShowBattleError",
    third = "其他分类"
  }
  local DescribeInfo = {
    title = "战斗报错",
    trace_content = Ret
  }
  local Avatar = GWorld:GetAvatar()
  if Avatar then
    Avatar:SendToFeishuForBattle(Ret, "战斗报错")
    Avatar:SendTraceToQaWeb(TraceType, DescribeInfo)
    return
  end
  local DSEntity = GWorld:GetDSEntity()
  if DSEntity then
    DSEntity:SendToFeishuForBattle(Ret, "战斗报错")
    DSEntity:SendTraceToQaWeb(TraceType, DescribeInfo)
    return
  end
end

function BP_Battle_C:GetLimitSeNumEachAttack()
  return Const.EveryAttackLimitSeNum
end

function BP_Battle_C:InitBannedRecordTags()
  local Arr = TArray(FName)
  local BannedRecordTags = EMCache:Get("BannedRecordTags")
  if BannedRecordTags and next(BannedRecordTags) then
    for Tag, _ in pairs(BannedRecordTags) do
      Arr:Add(Tag)
    end
  end
  self:SetBannedRecordTags(Arr)
end

function BP_Battle_C:ShowError_Monster_Inner_Lua(Text, Title)
  if nil == Title then
    Title = "怪物组报错"
  end
  local bDistribution = UE4.URuntimeCommonFunctionLibrary.IsDistribution()
  local bEnableShippingLog = UE4.URuntimeCommonFunctionLibrary.EnableLogInShipping()
  if bDistribution and not bEnableShippingLog then
    return
  end
  local Space = "=========================================================\n"
  local ct = {
    Space,
    "报错文本:\n\t",
    tostring(Text),
    "\n"
  }
  local ret
  table.insert(ct, Space)
  table.insert(ct, [[
Traceback:
	]])
  table.insert(ct, debug.traceback())
  table.insert(ct, "\n")
  table.insert(ct, Space)
  self:FillLog_Monster(ct)
  ret = table.concat(ct)
  if not GWorld.ErrorDict then
    GWorld.ErrorDict = {}
  end
  if GWorld.ErrorDict[Text] then
    return
  end
  GWorld.ErrorDict[Text] = true
  local Avatar = GWorld:GetAvatar()
  if Avatar then
    local LocalUser = UE.UKismetSystemLibrary:GetPlatformUserName()
    local ret = "设备名：" .. LocalUser .. "\n" .. ret
    Avatar:CallServerMethod("SendToFeiShuForMonster", ret, Title)
    return
  end
  local DSEntity = GWorld:GetDSEntity()
  if DSEntity then
    DSEntity:SendToFeishuForMonster(ret, Title)
    return
  end
end

function BP_Battle_C:FillLog_Monster(ct)
  local Avatar = GWorld:GetAvatar()
  table.insert(ct, "环境:")
  if IsClient(self) then
    table.insert(ct, "联机客户端\n")
  elseif IsDedicatedServer(self) then
    table.insert(ct, "联机服务端\n")
  elseif Avatar and Avatar:IsInHardBoss() then
    table.insert(ct, "梦魇残声")
    if Avatar.HardBossInfo then
      table.insert(ct, ":编号[")
      local HardBossId = Avatar.HardBossInfo.HardBossId
      table.insert(ct, HardBossId)
      table.insert(ct, "]")
      local Context
      if DataMgr.HardBossMain[HardBossId] then
        local HardBossName = DataMgr.HardBossMain[HardBossId].HardBossName
        if DataMgr.TextMap[HardBossName] then
          Context = GText(HardBossName)
        end
      end
      if Context then
        table.insert(ct, "[")
        table.insert(ct, Context)
        table.insert(ct, "]")
      end
      local DifficultyId = Avatar.HardBossInfo.DifficultyId
      local DifficultyLevel
      if DifficultyId and DataMgr.HardBossDifficulty[DifficultyId] then
        DifficultyLevel = DataMgr.HardBossDifficulty[DifficultyId].DifficultyLevel
      end
      table.insert(ct, ":难度等级[")
      table.insert(ct, DifficultyLevel)
      table.insert(ct, "]")
    end
    table.insert(ct, "\n")
  else
    table.insert(ct, "单机\n")
  end
  local GameMode = UE4.UGameplayStatics.GetGameMode(self)
  if IsDedicatedServer(self) then
    local AllPlayer = GameMode:GetAllPlayer()
    for i, Player in pairs(AllPlayer) do
      table.insert(ct, "[")
      table.insert(ct, i)
      table.insert(ct, "]")
      self:FillCharacterLog_Monster(ct, Player)
      table.insert(ct, "\n")
    end
  else
    local Player = UE4.UGameplayStatics.GetPlayerCharacter(self, 0)
    local CurrentRoleId
    if Player then
      CurrentRoleId = Player.CurrentRoleId
    end
    self:FillCharacterLog_Monster(ct, Player)
    table.insert(ct, "\n")
  end
  local GameState = UE.UGameplayStatics.GetGameState(self.Player)
  if IsValid(GameState) then
    local DungeonId = GameState.DungeonId
    if DungeonId and DungeonId > 0 then
      table.insert(ct, "副本ID:")
      table.insert(ct, tostring(DungeonId))
      local DungeonInfo = DataMgr.Dungeon[DungeonId]
      if DungeonInfo then
        local DungeonName = DungeonInfo.DungeonName
        if DataMgr.TextMap[DungeonName] then
          DungeonName = GText(DungeonName)
        end
        table.insert(ct, "(")
        table.insert(ct, tostring(DungeonName))
        table.insert(ct, ")")
      end
      table.insert(ct, "\n")
    end
  end
  if IsValid(GameMode) and GameMode:IsInRegion() and Avatar then
    local RegionId = Avatar:GetCurrentRegionId()
    table.insert(ct, "子区域ID:")
    table.insert(ct, tostring(RegionId))
    local RegionInfo = DataMgr.SubRegion[RegionId]
    if RegionInfo then
      local RegionName = RegionInfo.SubRegionName
      if DataMgr.TextMap[RegionName] then
        RegionName = GText(RegionName)
      end
      table.insert(ct, "(")
      table.insert(ct, tostring(RegionName))
      table.insert(ct, ")")
    end
    table.insert(ct, "\n")
  end
  table.insert(ct, Space)
end

function BP_Battle_C:FillCharacterLog_Monster(ct, Player)
  if not Player then
    return
  end
  local CurrentRoleId = Player.CurrentRoleId
  table.insert(ct, "使用角色ID:")
  table.insert(ct, tostring(CurrentRoleId))
  if DataMgr.BattleChar[CurrentRoleId] then
    local RoleName = GText(DataMgr.BattleChar[CurrentRoleId].CharName)
    table.insert(ct, "(")
    table.insert(ct, tostring(RoleName))
    table.insert(ct, ")")
  end
  if Player:IsPlayer() then
    local Flag = false
    local PhantomTeammate = Player:GetPhantomTeammates()
    for _, Target in pairs(PhantomTeammate) do
      if Target ~= Player then
        if not Flag then
          table.insert(ct, "\n正在使用的魅影信息:")
          Flag = true
        end
        table.insert(ct, [[

	]])
        self:FillCharacterLog_Monster(ct, Target)
      end
    end
  end
end

function BP_Battle_C:ShowError_UI_Inner_Lua(Text, Title)
  if nil == Title then
    Title = "UI组报错"
  end
  local bDistribution = UE4.URuntimeCommonFunctionLibrary.IsDistribution()
  local bEnableShippingLog = UE4.URuntimeCommonFunctionLibrary.EnableLogInShipping()
  if bDistribution and not bEnableShippingLog then
    return
  end
  local Space = "=========================================================\n"
  local ct = {
    Space,
    "报错文本:\n\t",
    tostring(Text),
    "\n"
  }
  local Ret
  table.insert(ct, Space)
  table.insert(ct, [[
Traceback:
	]])
  table.insert(ct, debug.traceback())
  table.insert(ct, "\n")
  table.insert(ct, Space)
  self:FillLog_UI(ct)
  Ret = table.concat(ct)
  if UE4.URuntimeCommonFunctionLibrary.IsPlayInEditor(self) then
    ScreenPrint("UI报错:\n" .. Ret)
  end
  if not GWorld.ErrorDict then
    GWorld.ErrorDict = {}
  end
  if GWorld.ErrorDict[Text] then
    return
  end
  GWorld.ErrorDict[Text] = true
  local TraceType = {
    first = "UI报错",
    second = "ShowError_UI_Inner_Lua",
    third = "其他分类"
  }
  local DescribeInfo = {title = "UI报错", trace_content = Ret}
  local Avatar = GWorld:GetAvatar()
  if Avatar then
    local LocalUser = UE.UKismetSystemLibrary:GetPlatformUserName()
    local DeviceData = "设备名：" .. LocalUser .. "\n" .. Ret
    Avatar:CallServerMethod("SendToFeiShuForUI", DeviceData, Title)
    Avatar:SendTraceToQaWeb(TraceType, DescribeInfo)
    return
  end
  local DSEntity = GWorld:GetDSEntity()
  if DSEntity then
    DSEntity:SendToFeishuForUI(Ret, Title)
    DSEntity:SendTraceToQaWeb(TraceType, DescribeInfo)
    return
  end
end

function BP_Battle_C:FillLog_UI(ct)
  local Avatar = GWorld:GetAvatar()
  table.insert(ct, "环境:")
  if IsClient(self) then
    table.insert(ct, "联机客户端\n")
  elseif IsDedicatedServer(self) then
    table.insert(ct, "联机服务端\n")
  elseif Avatar and Avatar:IsInHardBoss() then
    table.insert(ct, "梦魇残声")
    if Avatar.HardBossInfo then
      table.insert(ct, ":编号[")
      local HardBossId = Avatar.HardBossInfo.HardBossId
      table.insert(ct, HardBossId)
      table.insert(ct, "]")
      local Context
      if DataMgr.HardBossMain[HardBossId] then
        local HardBossName = DataMgr.HardBossMain[HardBossId].HardBossName
        if DataMgr.TextMap[HardBossName] then
          Context = GText(HardBossName)
        end
      end
      if Context then
        table.insert(ct, "[")
        table.insert(ct, Context)
        table.insert(ct, "]")
      end
      local DifficultyId = Avatar.HardBossInfo.DifficultyId
      local DifficultyLevel
      if DifficultyId and DataMgr.HardBossDifficulty[DifficultyId] then
        DifficultyLevel = DataMgr.HardBossDifficulty[DifficultyId].DifficultyLevel
      end
      table.insert(ct, ":难度等级[")
      table.insert(ct, DifficultyLevel)
      table.insert(ct, "]")
    end
    table.insert(ct, "\n")
  else
    table.insert(ct, "单机\n")
  end
  local GameMode = UE4.UGameplayStatics.GetGameMode(self)
  if IsDedicatedServer(self) then
    local AllPlayer = GameMode:GetAllPlayer()
    for i, Player in pairs(AllPlayer) do
      table.insert(ct, "[")
      table.insert(ct, i)
      table.insert(ct, "]")
      self:FillCharacterLog_UI(ct, Player)
      table.insert(ct, "\n")
    end
  else
    local Player = UE4.UGameplayStatics.GetPlayerCharacter(self, 0)
    local CurrentRoleId
    if Player then
      CurrentRoleId = Player.CurrentRoleId
    end
    self:FillCharacterLog_UI(ct, Player)
    table.insert(ct, "\n")
  end
  local GameState = UE.UGameplayStatics.GetGameState(self.Player)
  if IsValid(GameState) then
    local DungeonId = GameState.DungeonId
    if DungeonId and DungeonId > 0 then
      table.insert(ct, "副本ID:")
      table.insert(ct, tostring(DungeonId))
      local DungeonInfo = DataMgr.Dungeon[DungeonId]
      if DungeonInfo then
        local DungeonName = DungeonInfo.DungeonName
        if DataMgr.TextMap[DungeonName] then
          DungeonName = GText(DungeonName)
        end
        table.insert(ct, "(")
        table.insert(ct, tostring(DungeonName))
        table.insert(ct, ")")
      end
      table.insert(ct, "\n")
    end
  end
  if IsValid(GameMode) and GameMode:IsInRegion() and Avatar then
    local RegionId = Avatar:GetCurrentRegionId()
    table.insert(ct, "子区域ID:")
    table.insert(ct, tostring(RegionId))
    local RegionInfo = DataMgr.SubRegion[RegionId]
    if RegionInfo then
      local RegionName = RegionInfo.SubRegionName
      if DataMgr.TextMap[RegionName] then
        RegionName = GText(RegionName)
      end
      table.insert(ct, "(")
      table.insert(ct, tostring(RegionName))
      table.insert(ct, ")")
    end
    table.insert(ct, "\n")
  end
  table.insert(ct, Space)
end

function BP_Battle_C:FillCharacterLog_UI(ct, Player)
  if not Player then
    return
  end
  local CurrentRoleId = Player.CurrentRoleId
  table.insert(ct, "使用角色ID:")
  table.insert(ct, tostring(CurrentRoleId))
  if DataMgr.BattleChar[CurrentRoleId] then
    local RoleName = GText(DataMgr.BattleChar[CurrentRoleId].CharName)
    table.insert(ct, "(")
    table.insert(ct, tostring(RoleName))
    table.insert(ct, ")")
  end
  if Player:IsPlayer() then
    local Flag = false
    local PhantomTeammate = Player:GetPhantomTeammates()
    for _, Target in pairs(PhantomTeammate) do
      if Target ~= Player then
        if not Flag then
          table.insert(ct, "\n正在使用的魅影信息:")
          Flag = true
        end
        table.insert(ct, [[

	]])
        self:FillCharacterLog_UI(ct, Target)
      end
    end
  end
end

function BP_Battle_C:IsInSettlement()
  return UIManager(self):GetUI("DungeonSettlement") ~= nil
end

AssembleComponents(BP_Battle_C)
return BP_Battle_C
