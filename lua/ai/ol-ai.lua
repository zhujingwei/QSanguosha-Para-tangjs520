-- 傲才
function sgs.ai_cardsview_valuable.aocai(self, class_name, player)
	if player:hasFlag("Global_AocaiFailed") or player:getPhase() ~= sgs.Player_NotActive then return end
	if class_name == "Slash" and sgs.Sanguosha:getCurrentCardUseReason() == sgs.CardUseStruct_CARD_USE_REASON_RESPONSE_USE then
		return "@AocaiCard=.:slash"
	elseif (class_name == "Peach" and player:getMark("Global_PreventPeach") == 0) or class_name == "Analeptic" then
		local dying = self.room:getCurrentDyingPlayer()
		if dying and dying:objectName() == player:objectName() then
			local user_string = "peach+analeptic"
			if player:getMark("Global_PreventPeach") > 0 then user_string = "analeptic" end
			return "@AocaiCard=.:" .. user_string
		else
			local user_string
			if class_name == "Analeptic" then user_string = "analeptic" else user_string = "peach" end
			return "@AocaiCard=.:" .. user_string
		end
	end
end

sgs.ai_skill_invoke.aocai = function(self, data)
	local asked = data:toStringList()
	local pattern = asked[1]
	local prompt = asked[2]
	return self:askForCard(pattern, prompt, 1) ~= "."
end

sgs.ai_skill_askforag.aocai = function(self, card_ids)
	local card = sgs.Sanguosha:getCard(card_ids[1])
	if card:isKindOf("Jink") and self.player:hasFlag("dahe") then
		for _, id in ipairs(card_ids) do
			if sgs.Sanguosha:getCard(id):getSuit() == sgs.Card_Heart then return id end
		end
		return -1
	end
	return card_ids[1]
end

-- 黩武
function SmartAI:getSaveNum(isFriend)
	local num = 0
	for _, player in sgs.qlist(self.room:getAllPlayers()) do
		if (isFriend and self:isFriend(player)) or (not isFriend and self:isEnemy(player)) then
			if not self.player:hasSkill("wansha") or player:objectName() == self.player:objectName() then
				if player:hasSkill("jijiu") then
					num = num + self:getSuitNum("heart", true, player)
					num = num + self:getSuitNum("diamond", true, player)
					num = num + player:getHandcardNum() * 0.4
				end
				if player:hasSkill("nosjiefan") and getCardsNum("Slash", player, self.player) > 0 then
					if self:isFriend(player) or self:getCardsNum("Jink") == 0 then num = num + getCardsNum("Slash", player, self.player) end
				end
				num = num + getCardsNum("Peach", player, self.player)
			end
			if player:hasSkill("buyi") and not player:isKongcheng() then num = num + 0.3 end
			if player:hasSkill("chunlao") and not player:getPile("wine"):isEmpty() then num = num + player:getPile("wine"):length() end
			if player:hasSkill("jiuzhu") and player:getHp() > 1 and not player:isNude() then
				num = num + 0.9 * math.max(0, math.min(player:getHp() - 1, player:getCardCount(true)))
			end
			if player:hasSkill("renxin") and player:objectName() ~= self.player:objectName() and not player:isKongcheng() then num = num + 1 end
		end
	end
	return num
end

local duwu_skill = {}
duwu_skill.name = "duwu"
table.insert(sgs.ai_skills, duwu_skill)
duwu_skill.getTurnUseCard = function(self, inclusive)
	if self.player:hasFlag("DuwuEnterDying") or #self.enemies == 0 then return end
	return sgs.Card_Parse("@DuwuCard=.")
end

sgs.ai_skill_use_func.DuwuCard = function(card, use, self)
	local cmp = function(a, b)
		if a:getHp() < b:getHp() then
			if a:getHp() == 1 and b:getHp() == 2 then return false else return true end
		end
		return false
	end
	local enemies = {}
	for _, enemy in ipairs(self.enemies) do
		if self:canAttack(enemy, self.player) and self.player:inMyAttackRange(enemy) then table.insert(enemies, enemy) end
	end
	if #enemies == 0 then return end
	table.sort(enemies, cmp)
	if enemies[1]:getHp() <= 0 then
		use.card = sgs.Card_Parse("@DuwuCard=.")
		if use.to then use.to:append(enemies[1]) end
		return
	end

	-- find cards
	local card_ids = {}
	if self:needToThrowArmor() then table.insert(card_ids, self.player:getArmor():getEffectiveId()) end

	local zcards = self.player:getHandcards()
	local use_slash, keep_jink, keep_analeptic = false, false, false
	for _, zcard in sgs.qlist(zcards) do
		if not isCard("Peach", zcard, self.player) and not isCard("ExNihilo", zcard, self.player) then
			local shouldUse = true
			if zcard:getTypeId() == sgs.Card_TypeTrick then
				local dummy_use = { isDummy = true }
				self:useTrickCard(zcard, dummy_use)
				if dummy_use.card then shouldUse = false end
			end
			if zcard:getTypeId() == sgs.Card_TypeEquip and not self.player:hasEquip(zcard) then
				local dummy_use = { isDummy = true }
				self:useEquipCard(zcard, dummy_use)
				if dummy_use.card then shouldUse = false end
			end
			if isCard("Jink", zcard, self.player) and not keep_jink then
				keep_jink = true
				shouldUse = false
			end
			if self.player:getHp() == 1 and isCard("Analeptic", zcard, self.player) and not keep_analeptic then
				keep_analeptic = true
				shouldUse = false
			end
			if shouldUse then table.insert(card_ids, zcard:getId()) end
		end
	end
	local hc_num = #card_ids
	local eq_num = 0
	if self.player:getOffensiveHorse() then
		table.insert(card_ids, self.player:getOffensiveHorse():getEffectiveId())
		eq_num = eq_num + 1
	end
	if self.player:getWeapon() and self:evaluateWeapon(self.player:getWeapon()) < 5 then
		table.insert(card_ids, self.player:getWeapon():getEffectiveId())
		eq_num = eq_num + 2
	end

	local function getRangefix(index)
		if index <= hc_num then return 0
		elseif index == hc_num + 1 then
			if eq_num == 2 then
				return sgs.weapon_range[self.player:getWeapon():getClassName()] - self.player:getAttackRange(false)
			else
				return 1
			end
		elseif index == hc_num + 2 then
			return sgs.weapon_range[self.player:getWeapon():getClassName()]
		end
	end

	for _, enemy in ipairs(enemies) do
		if enemy:getHp() > #card_ids then continue end
		if enemy:getHp() <= 0 then
			use.card = sgs.Card_Parse("@DuwuCard=.")
			if use.to then use.to:append(enemy) end
			return
		elseif enemy:getHp() > 1 then
			local hp_ids = {}
			if self.player:distanceTo(enemy, getRangefix(enemy:getHp())) <= self.player:getAttackRange() then
				for _, id in ipairs(card_ids) do
					table.insert(hp_ids, id)
					if #hp_ids == enemy:getHp() then break end
				end
				use.card = sgs.Card_Parse("@DuwuCard=" .. table.concat(hp_ids, "+"))
				if use.to then use.to:append(enemy) end
				return
			end
		else
			if not self:isWeak() or self:getSaveNum(true) >= 1 then
				if self.player:distanceTo(enemy, getRangefix(1)) <= self.player:getAttackRange() then
					use.card = sgs.Card_Parse("@DuwuCard=" .. card_ids[1])
					if use.to then use.to:append(enemy) end
					return
				end
			end
		end
	end
end

sgs.ai_use_priority.DuwuCard = 0.6
sgs.ai_use_value.DuwuCard = 2.45
sgs.dynamic_value.damage_card.DuwuCard = true
sgs.ai_card_intention.DuwuCard = 80

-- 独进
sgs.ai_skill_invoke.dujin = sgs.ai_skill_invoke.biyue

-- 轻逸
sgs.ai_skill_use["@@qingyi"] = function(self, prompt)
	local card_str = sgs.ai_skill_use["@@shensu1"](self, "@shensu1")
	return string.gsub(card_str, "ShensuCard", "QingyiCard")
end

sgs.ai_card_intention.QingyiCard = sgs.ai_card_intention.Slash

-- 奋音
sgs.ai_skill_invoke.fenyin = sgs.ai_skill_invoke.biyue

-- 屯储
sgs.ai_skill_invoke["tunchu"] = function(self, data)
	if #self.enemies == 0 then
		return true
	end
	local callback = sgs.ai_skill_choice.jiangchi
	local choice = callback(self, "jiang+chi+cancel")
	if choice == "jiang" then
		return true
	end
	for _, friend in ipairs(self.friends_noself) do
		if (friend:getHandcardNum() < 2 or (friend:hasSkill("rende") and friend:getHandcardNum() < 3)) and choice == "cancel" then
		return true
		end
	end
	return false
end

-- 输粮
sgs.ai_skill_use["@@shuliang"] = function(self, prompt, method)
	local target = self.room:getCurrent()
	if target and self:isFriend(target) then
		return "@ShuliangCard=" .. self.player:getPile("food"):first()
	end
	return "."
end

-- 战意
local zhanyi_skill = {}
zhanyi_skill.name = "zhanyi"
table.insert(sgs.ai_skills, zhanyi_skill)
zhanyi_skill.getTurnUseCard = function(self)

	if not self.player:hasUsed("ZhanyiCard") then
		return sgs.Card_Parse("@ZhanyiCard=.")
	end

	if self.player:getMark("ViewAsSkill_zhanyiEffect") > 0 then
		local use_basic = self:ZhanyiUseBasic()
		local cards = self.player:getCards("h")
		cards=sgs.QList2Table(cards)
		self:sortByUseValue(cards, true)
		local BasicCards = {}
		for _, card in ipairs(cards) do
			if card:isKindOf("BasicCard") then
				table.insert(BasicCards, card)
			end
		end
		if use_basic and #BasicCards > 0 then
			return sgs.Card_Parse("@ZhanyiViewAsBasicCard=" .. BasicCards[1]:getId() .. ":"..use_basic)
		end
	end
end

sgs.ai_skill_use_func.ZhanyiCard = function(card, use, self)
	local to_discard
	local cards = self.player:getCards("h")
	cards=sgs.QList2Table(cards)
	self:sortByUseValue(cards, true)

	local TrickCards = {}
	for _, card in ipairs(cards) do
		if card:isKindOf("Disaster") or card:isKindOf("GodSalvation") or card:isKindOf("AmazingGrace") or self:getCardsNum("TrickCard") > 1 then
			table.insert(TrickCards, card)
		end
	end
	if #TrickCards > 0 and (self.player:getHp() > 2 or self:getCardsNum("Peach") > 0 ) and self.player:getHp() > 1 then
		to_discard = TrickCards[1]
	end

	local EquipCards = {}
	if self:needToThrowArmor() and self.player:getArmor() then table.insert(EquipCards,self.player:getArmor()) end
	for _, card in ipairs(cards) do
		if card:isKindOf("EquipCard") then
			table.insert(EquipCards, card)
		end
	end
	if not self:isWeak() and self.player:getDefensiveHorse() then table.insert(EquipCards,self.player:getDefensiveHorse()) end
	if self.player:hasTreasure("wooden_ox") and self.player:getPile("wooden_ox"):length() == 0 then table.insert(EquipCards,self.player:getTreasure()) end
	self:sort(self.enemies, "defense")
	if self:getCardsNum("Slash") > 0 and
	((self.player:getHp() > 2 or self:getCardsNum("Peach") > 0 ) and self.player:getHp() > 1) then
		for _, enemy in ipairs(self.enemies) do
			if (self:isWeak(enemy)) or (enemy:getCardCount(true) <= 4 and enemy:getCardCount(true) >=1)
				and self.player:canSlash(enemy) and self:slashIsEffective(sgs.Sanguosha:cloneCard("slash"), enemy, self.player)
				and self.player:inMyAttackRange(enemy) and not self:needToThrowArmor(enemy) then
				to_discard = EquipCards[1]
				break
			end
		end
	end

	local BasicCards = {}
	for _, card in ipairs(cards) do
		if card:isKindOf("BasicCard") then
			table.insert(BasicCards, card)
		end
	end
	local use_basic = self:ZhanyiUseBasic()
	if (use_basic == "peach" and self.player:getHp() > 1 and #BasicCards > 3)
	--or (use_basic == "analeptic" and self.player:getHp() > 1 and #BasicCards > 2)
	or (use_basic == "slash" and self.player:getHp() > 1 and #BasicCards > 1)
	then
		to_discard = BasicCards[1]
	end

	if to_discard then
		use.card = sgs.Card_Parse("@ZhanyiCard=" .. to_discard:getEffectiveId())
		return
	end
end

sgs.ai_use_priority.ZhanyiCard = 10

sgs.ai_skill_use_func.ZhanyiViewAsBasicCard=function(card,use,self)
	local userstring=card:toString()
	userstring=(userstring:split(":"))[3]
	local zhanyicard=sgs.Sanguosha:cloneCard(userstring, card:getSuit(), card:getNumber())
	zhanyicard:setSkillName("zhanyi")
	if zhanyicard:getTypeId() == sgs.Card_TypeBasic then
		if not use.isDummy and use.card and zhanyicard:isKindOf("Slash") and (not use.to or use.to:isEmpty()) then return end
		self:useBasicCard(zhanyicard, use)
	end
	if not use.card then return end
	use.card=card
end

sgs.ai_use_priority.ZhanyiViewAsBasicCard = 8

function SmartAI:ZhanyiUseBasic()
	local has_slash = false
	local has_peach = false
	--local has_analeptic = false

	local cards = self.player:getCards("h")
	cards=sgs.QList2Table(cards)
	self:sortByUseValue(cards, true)
	local BasicCards = {}
	for _, card in ipairs(cards) do
		if card:isKindOf("BasicCard") then
			table.insert(BasicCards, card)
			if card:isKindOf("Slash") then has_slash = true end
			if card:isKindOf("Peach") then has_peach = true end
			--if card:isKindOf("Analeptic") then has_analeptic = true end
		end
	end

	if #BasicCards <= 1 then return nil end

	local ban = table.concat(sgs.Sanguosha:getBanPackages(), "|")
	self:sort(self.enemies, "defense")
	for _, enemy in ipairs(self.enemies) do
		if (self:isWeak(enemy))
		and self.player:canSlash(enemy) and self:slashIsEffective(sgs.Sanguosha:cloneCard("slash"), enemy, self.player)
		and self.player:inMyAttackRange(enemy) then
			--if not has_analeptic and not ban:match("maneuvering") and self.player:getMark("drank") == 0
				--and getKnownCard(enemy, self.player, "Jink") == 0 and #BasicCards > 2 then return "analeptic" end
			if not has_slash then return "slash" end
		end
	end

	if self:isWeak() and not has_peach then return "peach" end

return nil
end

sgs.ai_skill_choice.zhanyi_saveself = function(self, choices)
	if self:getCard("Peach") or not self:getCard("Analeptic") then return "peach" else return "analeptic" end
end

sgs.ai_skill_choice.zhanyi_slash = function(self, choices)
	return "slash"
end

-- 避乱
sgs.ai_skill_invoke.biluan = function(self, data)
	local kingdoms = {}
	local cantAttackme = 0
	for _, p in sgs.qlist(self.room:getAlivePlayers()) do
		if not table.contains(kingdoms, p:getKingdom()) then
			table.insert(kingdoms, p:getKingdom())
		end
	end
	for _,p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		if p:getAttackRange() < p:distanceTo(self.player) + #kingdoms then
			cantAttackme = cantAttackme + 1
		end
	end
	return cantAttackme > 3
end

-- 礼下
sgs.ai_skill_invoke.lixia = sgs.ai_skill_invoke.biyue

-- 义舍
sgs.ai_skill_invoke.yishe = function(self, data)
	return true
end

-- 布施
sgs.ai_skill_use["@@bushi"] = function(self, prompt, method)
	local zhanglu = self.room:findPlayerBySkillName("bushi")
	if not zhanglu or zhanglu:getPile("rice"):length() < 1 then return "." end
	if self:isEnemy(zhanglu) and zhanglu:getPile("rice"):length() == 1 and zhanglu:isWounded() then return "." end
	if self:isFriend(zhanglu) and (not (zhanglu:getPile("rice"):length() == 1 and zhanglu:isWounded())) and self:getOverflow() > 1 then return "." end
	local cards = {}
	for _,id in sgs.qlist(zhanglu:getPile("rice")) do
		table.insert(cards,sgs.Sanguosha:getCard(id))
	end
	self:sortByUseValue(cards, true)
	return "@BushiCard="..cards[1]:getEffectiveId()	
end	

-- 米道
sgs.ai_skill_use["@@midao"] = function(self, prompt, method)
	local judge = self.player:getTag("judgeData"):toJudge()
	local ids = self.player:getPile("rice")
	if self.room:getMode():find("_mini_46") and not judge:isGood() then return "@MidaoCard=" .. ids:first() end
	if self:needRetrial(judge) then
		local cards = {}
		for _,id in sgs.qlist(ids) do
			table.insert(cards,sgs.Sanguosha:getCard(id))
		end
		local card_id = self:getRetrialCardId(cards, judge)
		if card_id ~= -1 then
			return "@MidaoCard=" .. card_id
		end
	end
	return "."	
end

-- 凤魄
sgs.ai_skill_choice.fengpo = function(self, choices, data)
	local use = data:toCardUse()
	if self:isFriend(use.to) then
		return "drawCards"
	end
	if self:needKongcheng(self.player, true) then
		return "addDamage"
	end
	if self:needBear() then
		return "drawCards"
	end
	if use.card:isKindOf("Duel") then
		return "addDamage"
	end
end
