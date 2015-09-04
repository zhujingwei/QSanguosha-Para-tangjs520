-- 银月枪
sgs.weapon_range.SPMoonSpear = 3

sgs.ai_skill_playerchosen.sp_moonspear = function(self, targets)
	targets = sgs.QList2Table(targets)
	self:sort(targets, "defense")
	for _, target in ipairs(targets) do
		if self:isEnemy(target) and self:damageIsEffective(target) and sgs.isGoodTarget(target, targets, self) then
			return target
		end
	end
	return nil
end

sgs.ai_playerchosen_intention.sp_moonspear = 80

-- 啖酪
sgs.ai_skill_invoke.danlao = function(self, data)
	local effect = data:toCardUse()
	local current = self.room:getCurrent()
	if effect.card:isKindOf("GodSalvation") and self.player:isWounded() or effect.card:isKindOf("ExNihilo") then
		return false
	elseif effect.card:isKindOf("AmazingGrace") and
		(self.player:getSeat() - current:getSeat()) % (global_room:alivePlayerCount()) < global_room:alivePlayerCount()/2 then
		return false
	else
		return true
	end
end

-- 鸡肋
sgs.ai_skill_invoke.jilei = function(self, data)
	local damage = data:toDamage()
	if not damage then return false end
	self.jilei_source = damage.from
	return self:isEnemy(damage.from)
end

sgs.ai_skill_choice.jilei = function(self, choices)
	local tmptrick = sgs.Sanguosha:cloneCard("ex_nihilo")
	if (self:hasCrossbowEffect(self.jilei_source) and self.jilei_source:inMyAttackRange(self.player))
		or self.jilei_source:isCardLimited(tmptrick, sgs.Card_MethodUse, true) then
		return "BasicCard"
	else
		return "TrickCard"
	end
end

-- 庸肆
sgs.ai_skill_discard.yongsi = function(self, discard_num, min_num, optional, include_equip)
	if optional then
		return {}
	end
	local flag = "h"
	local equips = self.player:getEquips()
	if include_equip and not (equips:isEmpty() or self.player:isJilei(equips:first())) then flag = flag .. "e" end
	local cards = self.player:getCards(flag)
	local to_discard = {}
	cards = sgs.QList2Table(cards)
	local aux_func = function(card)
		local place = self.room:getCardPlace(card:getEffectiveId())
		if place == sgs.Player_PlaceEquip then
			if card:isKindOf("SilverLion") then
				local players = self.room:getOtherPlayers(self.player)
				for _,p in sgs.qlist(players) do
					local blade = p:getWeapon()
					if blade and blade:isKindOf("GudingBlade") then
						if p:inMyAttackRange(self.player) then
							if self:isEnemy(p, self.player) then
								return 6
							end
						else
							break --因为只有一把古锭刀，检测到有人装备了，其他人就不会再装备了，此时可跳出检测。
						end
					end
				end
				if self.player:isWounded() then
					return -2
				end
			elseif card:isKindOf("Weapon") and self.player:getHandcardNum() < discard_num + 2 and not self:needKongcheng() then return 0
			elseif card:isKindOf("OffensiveHorse") and self.player:getHandcardNum() < discard_num + 2 and not self:needKongcheng() then return 0
			elseif card:isKindOf("OffensiveHorse") then return 1
			elseif card:isKindOf("Weapon") then return 2
			elseif card:isKindOf("DefensiveHorse") then return 3
			elseif self:hasSkills("bazhen|yizhong") and card:isKindOf("Armor") then return 0
			elseif card:isKindOf("Armor") then
				return 4
			end
		elseif self:hasSkills(sgs.lose_equip_skill) then
			return 5
		else
			return 0
		end
		return 0
	end
	local compare_func = function(a, b)
		if aux_func(a) ~= aux_func(b) then return aux_func(a) < aux_func(b) end
		return self:getKeepValue(a) < self:getKeepValue(b)
	end

	table.sort(cards, compare_func)
	local least = min_num
	if discard_num - min_num > 1 then
		least = discard_num -1
	end
	for _, card in ipairs(cards) do
		if not self.player:isJilei(card) then
			table.insert(to_discard, card:getId())
		end
		if (self.player:hasSkill("qinyin") and #to_discard >= least) or #to_discard >= discard_num then
			break
		end
	end
	return to_discard
end

-- 良助
sgs.ai_skill_choice.liangzhu = function(self, choices, data)
	local current = self.room:getCurrent()
	if self:isFriend(current) and (self:isWeak(current) or current:hasSkills(sgs.cardneed_skill))then
		return "letdraw"
	end
	return "draw"
end

-- 怒斩
sgs.ai_cardneed.nuzhan = function(to, card)
	return card:isRed() and (card:isKindOf("TrickCard") or card:isKindOf("EquipCard"))
end

-- 修罗
sgs.ai_skill_cardask["@xiuluo"] = function(self, data, pattern)
	if self.player:containsTrick("YanxiaoCard") then return "." end
	if not self.player:containsTrick("indulgence") and not self.player:containsTrick("supply_shortage")
		and not (self.player:containsTrick("lightning") and not self:hasWizard(self.enemies)) then return "." end
	local indul_suit, ss_suit, lightning_suit = nil, nil, nil
	for _, card in sgs.qlist(self.player:getJudgingArea()) do
		if card:isKindOf("Indulgence") then indul_suit = card:getSuit() end
		if card:isKindOf("SupplyShortage") then ss_suit = card:getSuit() end
		if card:isKindOf("Lightning") then ss_suit = card:getSuit() end
	end
	if ss_suit then
		for _, card in sgs.qlist(self.player:getHandcards()) do
			if card:getSuit() == ss_suit then return "$" .. card:getEffectiveId() end
		end
	elseif indul_suit then
		for _, card in sgs.qlist(self.player:getHandcards()) do
			if card:getSuit() == indul_suit and not isCard("Peach", self.player, card) then return "$" .. card:getEffectiveId() end
		end
	elseif lightning_suit then
		for _, card in sgs.qlist(self.player:getHandcards()) do
			if card:getSuit() == lightning_suit and not isCard("Peach", self.player, card) then return "$" .. card:getEffectiveId() end
		end
	end
	return "."
end

sgs.ai_skill_askforag.xiuluo = function(self, card_ids)
	for _, id in ipairs(card_ids) do
		local card = sgs.Sanguosha:getCard(id)
		if card:isKindOf("SupplyShortage") then return id end
	end
	for _, id in ipairs(card_ids) do
		local card = sgs.Sanguosha:getCard(id)
		if card:isKindOf("Indulgence") then return id end
	end
	if self:hasWizard(self.enemies) and self.player:containsTrick("lightning") then
		for _, id in ipairs(card_ids) do
			local card = sgs.Sanguosha:getCard(id)
			if card:isKindOf("Lightning") then return id end
		end
	end
	return card_ids[1]
end

-- 陈情
sgs.ai_skill_playerchosen.chenqing = function(self, targets)
	targets = sgs.QList2Table(targets)
	self:sort(targets, "defense")
	local toChooses = {}
	for _, target in ipairs(targets) do
		if self:isFriend(target) or target:isNude() then
			table.insert(toChooses, target)
		end
	end
	local toChoose = toChooses[1]
	for _, target in ipairs(toChooses) do
		if (target:getHandcardNum() + target:getEquips():length()) > (toChoose:getHandcardNum() + toChoose:getEquips():length()) then
			toChoose = target
		end
	end
	if toChoose ~= nil then
		return toChoose
	end
	return nil
end

-- 默识

-- 刺槐
sgs.ai_skill_invoke.cihuai = function(self, data)
	local has_slash = false
	local cards = self.player:getCards("h")
	cards=sgs.QList2Table(cards)
	for _, card in ipairs(cards) do
		if card:isKindOf("Slash") then has_slash = true end
	end
	if has_slash then return false end

	self:sort(self.enemies, "defenseSlash")
	for _, enemy in ipairs(self.enemies) do
		local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
		local eff = self:slashIsEffective(slash, enemy) and sgs.isGoodTarget(enemy, self.enemies, self)
		if eff and self.player:canSlash(enemy) and not self:slashProhibit(nil, enemy) then
			return true
		end
	end

return false
end

local cihuai_skill = {}
cihuai_skill.name = "cihuai"
table.insert(sgs.ai_skills, cihuai_skill)
cihuai_skill.getTurnUseCard = function(self)
	if self.player:getMark("@cihuai") > 0 then
		local card_str = ("slash:_cihuai[no_suit:0]=.")
		local slash = sgs.Card_Parse(card_str)
		assert(slash)
		return slash
	end
end

-- 援护
local function yuanhu_validate(self, equip_type, is_handcard)
	local is_SilverLion = false
	if equip_type == "SilverLion" then
		equip_type = "Armor"
		is_SilverLion = true
	end
	local targets
	if is_handcard then targets = self.friends else targets = self.friends_noself end
	if equip_type ~= "Weapon" then
		if equip_type == "DefensiveHorse" or equip_type == "OffensiveHorse" then self:sort(targets, "hp") end
		if equip_type == "Armor" then self:sort(targets, "handcard") end
		if is_SilverLion then
			for _, enemy in ipairs(self.enemies) do
				if enemy:hasSkill("kongcheng") and enemy:isKongcheng() then
					local seat_diff = enemy:getSeat() - self.player:getSeat()
					local alive_count = self.room:alivePlayerCount()
					if seat_diff < 0 then seat_diff = seat_diff + alive_count end
					if seat_diff > alive_count / 2.5 + 1 then return enemy  end
				end
			end
			for _, enemy in ipairs(self.enemies) do
				if self:hasSkills("bazhen|yizhong", enemy) then
					return enemy
				end
			end
		end
		for _, friend in ipairs(targets) do
			local has_equip = false
			for _, equip in sgs.qlist(friend:getEquips()) do
				if equip:isKindOf(equip_type) then
					has_equip = true
					break
				end
			end
			if not has_equip then
				if equip_type == "Armor" then
					if not self:needKongcheng(friend, true) and not self:hasSkills("bazhen|yizhong", friend) then return friend end
				else
					if friend:isWounded() and not (friend:hasSkill("longhun") and friend:getCardCount(true) >= 3) then return friend end
				end
			end
		end
	else
		for _, friend in ipairs(targets) do
			local has_equip = false
			for _, equip in sgs.qlist(friend:getEquips()) do
				if equip:isKindOf(equip_type) then
					has_equip = true
					break
				end
			end
			if not has_equip then
				for _, aplayer in sgs.qlist(self.room:getAllPlayers()) do
					if friend:distanceTo(aplayer) == 1 then
						if self:isFriend(aplayer) and not aplayer:containsTrick("YanxiaoCard")
							and (aplayer:containsTrick("indulgence") or aplayer:containsTrick("supply_shortage")
								or (aplayer:containsTrick("lightning") and self:hasWizard(self.enemies))) then
							aplayer:setFlags("AI_YuanhuToChoose")
							return friend
						end
					end
				end
				self:sort(self.enemies, "defense")
				for _, enemy in ipairs(self.enemies) do
					if friend:distanceTo(enemy) == 1 and self.player:canDiscard(enemy, "he") then
						enemy:setFlags("AI_YuanhuToChoose")
						return friend
					end
				end
			end
		end
	end
	return nil
end

sgs.ai_skill_use["@@yuanhu"] = function(self, prompt)
	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	self:sortByKeepValue(cards)
	if self.player:hasArmorEffect("silver_lion") then
		local player = yuanhu_validate(self, "SilverLion", false)
		if player then return "@YuanhuCard=" .. self.player:getArmor():getEffectiveId() .. "->" .. player:objectName() end
	end
	if self.player:getOffensiveHorse() then
		local player = yuanhu_validate(self, "OffensiveHorse", false)
		if player then return "@YuanhuCard=" .. self.player:getOffensiveHorse():getEffectiveId() .. "->" .. player:objectName() end
	end
	if self.player:getWeapon() then
		local player = yuanhu_validate(self, "Weapon", false)
		if player then return "@YuanhuCard=" .. self.player:getWeapon():getEffectiveId() .. "->" .. player:objectName() end
	end
	if self.player:getArmor() and self.player:getLostHp() <= 1 and self.player:getHandcardNum() >= 3 then
		local player = yuanhu_validate(self, "Armor", false)
		if player then return "@YuanhuCard=" .. self.player:getArmor():getEffectiveId() .. "->" .. player:objectName() end
	end
	for _, card in ipairs(cards) do
		if card:isKindOf("DefensiveHorse") then
			local player = yuanhu_validate(self, "DefensiveHorse", true)
			if player then return "@YuanhuCard=" .. card:getEffectiveId() .. "->" .. player:objectName() end
		end
	end
	for _, card in ipairs(cards) do
		if card:isKindOf("OffensiveHorse") then
			local player = yuanhu_validate(self, "OffensiveHorse", true)
			if player then return "@YuanhuCard=" .. card:getEffectiveId() .. "->" .. player:objectName() end
		end
	end
	for _, card in ipairs(cards) do
		if card:isKindOf("Weapon") then
			local player = yuanhu_validate(self, "Weapon", true)
			if player then return "@YuanhuCard=" .. card:getEffectiveId() .. "->" .. player:objectName() end
		end
	end
	for _, card in ipairs(cards) do
		if card:isKindOf("SilverLion") then
			local player = yuanhu_validate(self, "SilverLion", true)
			if player then return "@YuanhuCard=" .. card:getEffectiveId() .. "->" .. player:objectName() end
		end
		if card:isKindOf("Armor") and yuanhu_validate(self, "Armor", true) then
			local player = yuanhu_validate(self, "Armor", true)
			if player then return "@YuanhuCard=" .. card:getEffectiveId() .. "->" .. player:objectName() end
		end
	end
end

sgs.ai_skill_playerchosen.yuanhu = function(self, targets)
	targets = sgs.QList2Table(targets)
	for _, p in ipairs(targets) do
		if p:hasFlag("AI_YuanhuToChoose") then
			p:setFlags("-AI_YuanhuToChoose")
			return p
		end
	end
	return targets[1]
end

sgs.ai_card_intention.YuanhuCard = function(self, card, from, to)
	if to[1]:hasSkill("bazhen") or to[1]:hasSkill("yizhong") or (to[1]:hasSkill("kongcheng") and to[1]:isKongcheng()) then
		if sgs.Sanguosha:getCard(card:getEffectiveId()):isKindOf("SilverLion") then
			sgs.updateIntention(from, to[1], 10)
			return
		end
	end
	sgs.updateIntention(from, to[1], -50)
end

sgs.ai_cardneed.yuanhu = sgs.ai_cardneed.equip

sgs.yuanhu_keep_value = {
	Peach = 6,
	Jink = 5.1,
	Weapon = 4.7,
	Armor = 4.8,
	Horse = 4.9
}

-- 血祭
sgs.ai_cardneed.xueji = function(to, card)
	return to:getHandcardNum() < 3 and card:isRed()
end

local xueji_skill = {}
xueji_skill.name = "xueji"
table.insert(sgs.ai_skills, xueji_skill)
xueji_skill.getTurnUseCard = function(self)
	if self.player:hasUsed("XuejiCard") then return end
	if not self.player:isWounded() then return end

	local card
	local cards = self.player:getCards("he")
	cards = sgs.QList2Table(cards)
	self:sortByUseValue(cards, true)

	for _, acard in ipairs(cards) do
		if acard:isRed() then
			card = acard
			break
		end
	end
	if card then
		card = sgs.Card_Parse("@XuejiCard=" .. card:getEffectiveId())
		return card
	end

	return nil
end

local function can_be_selected_as_target_xueji(self, card, who)
	-- validation of rule
	if self.player:getWeapon() and self.player:getWeapon():getEffectiveId() == card:getEffectiveId() then
		if self.player:distanceTo(who, sgs.weapon_range[self.player:getWeapon():getClassName()] - self.player:getAttackRange(false)) > self.player:getAttackRange() then return false end
	elseif self.player:getOffensiveHorse() and self.player:getOffensiveHorse():getEffectiveId() == card:getEffectiveId() then
		if self.player:distanceTo(who, 1) > self.player:getAttackRange() then return false end
	elseif self.player:distanceTo(who) > self.player:getAttackRange() then
		return false
	end
	-- validation of strategy
	if self:isEnemy(who) and self:damageIsEffective(who) and not self:cantbeHurt(who) and not self:getDamagedEffects(who) and not self:needToLoseHp(who) then
		if not self.player:hasSkill("jueqing") then
			if who:hasSkill("guixin") and (self.room:getAliveCount() >= 4 or not who:faceUp()) and not who:hasSkill("manjuan") then return false end
			if (who:hasSkill("ganglie") or who:hasSkill("neoganglie")) and (self.player:getHp() == 1 and self.player:getHandcardNum() <= 2) then return false end
			if who:hasSkill("jieming") then
				for _, enemy in ipairs(self.enemies) do
					if enemy:getHandcardNum() <= enemy:getMaxHp() - 2 and not enemy:hasSkill("manjuan") then return false end
				end
			end
			if who:hasSkill("fangzhu") then
				for _, enemy in ipairs(self.enemies) do
					if not enemy:faceUp() then return false end
				end
			end
			if who:hasSkill("yiji") then
				local huatuo = self.room:findPlayerBySkillName("jijiu")
				if huatuo and self:isEnemy(huatuo) and huatuo:getHandcardNum() >= 3 then
					return false
				end
			end
		end
		return true
	elseif self:isFriend(who) then
		if who:hasSkill("yiji") and not self.player:hasSkill("jueqing") then
			local huatuo = self.room:findPlayerBySkillName("jijiu")
			if (huatuo and self:isFriend(huatuo) and huatuo:getHandcardNum() >= 3 and huatuo ~= self.player)
				or (who:getLostHp() == 0 and who:getMaxHp() >= 3) then
				return true
			end
		end
		if who:hasSkill("hunzi") and who:getMark("hunzi") == 0
		  and who:objectName() == self.player:getNextAlive():objectName() and who:getHp() == 2 then
			return true
		end
		if self:cantbeHurt(who) and not self:damageIsEffective(who) and not (who:hasSkill("manjuan") and who:getPhase() == sgs.Player_NotActive)
		  and not (who:hasSkill("kongcheng") and who:isKongcheng()) then
			return true
		end
		return false
	end
	return false
end

sgs.ai_skill_use_func.XuejiCard = function(card, use, self)
	if self.player:getLostHp() == 0 or self.player:hasUsed("XuejiCard") then return end
	self:sort(self.enemies)
	local to_use = false
	for _, enemy in ipairs(self.enemies) do
		if can_be_selected_as_target_xueji(self, card, enemy) then
			to_use = true
			break
		end
	end
	if not to_use then
		for _, friend in ipairs(self.friends_noself) do
			if can_be_selected_as_target_xueji(self, card, friend) then
				to_use = true
				break
			end
		end
	end
	if to_use then
		use.card = card
		if use.to then
			for _, enemy in ipairs(self.enemies) do
				if can_be_selected_as_target_xueji(self, card, enemy) then
					use.to:append(enemy)
					if use.to:length() == self.player:getLostHp() then return end
				end
			end
			for _, friend in ipairs(self.friends_noself) do
				if can_be_selected_as_target_xueji(self, card, friend) then
					use.to:append(friend)
					if use.to:length() == self.player:getLostHp() then return end
				end
			end
			assert(use.to:length() > 0)
		end
	end
end

sgs.ai_card_intention.XuejiCard = function(self, card, from, tos)
	local room = from:getRoom()
	local huatuo = room:findPlayerBySkillName("jijiu")
	for _,to in ipairs(tos) do
		local intention = 60
		if to:hasSkill("yiji") and not from:hasSkill("jueqing") then
			if (huatuo and self:isFriend(huatuo) and huatuo:getHandcardNum() >= 3 and huatuo:objectName() ~= from:objectName()) then
				intention = -30
			end
			if to:getLostHp() == 0 and to:getMaxHp() >= 3 then
				intention = -10
			end
		end
		if to:hasSkill("hunzi") and to:getMark("hunzi") == 0 then
			if to:objectName() == from:getNextAlive():objectName() and to:getHp() == 2 then
				intention = -20
			end
		end
		if self:cantbeHurt(to) and not self:damageIsEffective(to) then intention = -20 end
		sgs.updateIntention(from, to, intention)
	end
end

sgs.ai_use_value.XuejiCard = 3
sgs.ai_use_priority.XuejiCard = 0.5

-- 虎啸
sgs.ai_cardneed.huxiao = sgs.ai_cardneed.lieren

-- 笔伐
sgs.ai_skill_use["@@bifa"] = function(self, prompt)
	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	self:sortByKeepValue(cards)
	self:sort(self.enemies, "hp")
	if #self.enemies < 0 then return "." end
	for _, enemy in ipairs(self.enemies) do
	if enemy:getPile("bifa"):length() > 0 then continue end
		if not (self:needToLoseHp(enemy) and not self:hasSkills(sgs.masochism_skill, enemy)) then
			for _, c in ipairs(cards) do
				if c:isKindOf("EquipCard") then return "@BifaCard=" .. c:getEffectiveId() .. "->" .. enemy:objectName() end
			end
			for _, c in ipairs(cards) do
				if c:isKindOf("TrickCard") and not (c:isKindOf("Nullification") and self:getCardsNum("Nullification") == 1) then
					return "@BifaCard=" .. c:getEffectiveId() .. "->" .. enemy:objectName()
				end
			end
			for _, c in ipairs(cards) do
				if c:isKindOf("Slash") then
					return "@BifaCard=" .. c:getEffectiveId() .. "->" .. enemy:objectName()
				end
			end
		end
	end
end

sgs.ai_skill_cardask["@bifa-give"] = function(self, data)
	local card_type = data:toString()
	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	if self:needToLoseHp() and not self:hasSkills(sgs.masochism_skill) then return "." end
	self:sortByUseValue(cards)
	for _, c in ipairs(cards) do
		if c:isKindOf(card_type) and not isCard("Peach", c, self.player) and not isCard("ExNihilo", c, self.player) then
			return "$" .. c:getEffectiveId()
		end
	end
	return "."
end

sgs.ai_card_intention.BifaCard = 30

sgs.bifa_keep_value = {
	Peach = 6,
	Jink = 5.1,
	Nullification = 5,
	EquipCard = 4.9,
	TrickCard = 4.8
}

-- 颂词
local songci_skill = {}
songci_skill.name = "songci"
table.insert(sgs.ai_skills, songci_skill)
songci_skill.getTurnUseCard = function(self)
	return sgs.Card_Parse("@SongciCard=.")
end

sgs.ai_skill_use_func.SongciCard = function(card,use,self)
	self:sort(self.friends, "handcard")
	for _, friend in ipairs(self.friends) do
		if friend:getMark("songci" .. self.player:objectName()) == 0 and friend:getHandcardNum() < friend:getHp() and not (friend:hasSkill("manjuan") and self.room:getCurrent() ~= friend) then
			if not (friend:hasSkill("kongcheng") and friend:isKongcheng()) then
				use.card = sgs.Card_Parse("@SongciCard=.")
				if use.to then use.to:append(friend) end
				return
			end
		end
	end

	self:sort(self.enemies, "handcard")
	self.enemies = sgs.reverse(self.enemies)
	for _, enemy in ipairs(self.enemies) do
		if enemy:getMark("songci" .. self.player:objectName()) == 0 and enemy:getHandcardNum() > enemy:getHp() and not enemy:isNude()
			and not self:doNotDiscard(enemy, "nil", false, 2) then
			use.card = sgs.Card_Parse("@SongciCard=.")
			if use.to then use.to:append(enemy) end
			return
		end
	end
end

sgs.ai_use_value.SongciCard = 3
sgs.ai_use_priority.SongciCard = 3

sgs.ai_card_intention.SongciCard = function(self, card, from, to)
	sgs.updateIntention(from, to[1], to[1]:getHandcardNum() > to[1]:getHp() and 80 or -80)
end

-- 星舞
sgs.ai_skill_cardask["@xingwu"] = function(self, data)
	local cards = sgs.QList2Table(self.player:getHandcards())
	if #cards <= 1 and self.player:getPile("xingwu"):length() == 1 then return "." end

	local good_enemies = {}
	for _, enemy in ipairs(self.enemies) do
		if enemy:isMale() and ((self:damageIsEffective(enemy) and not self:cantbeHurt(enemy, self.player, 2))
								or (not self:damageIsEffective(enemy) and not enemy:getEquips():isEmpty()
									and not (enemy:getEquips():length() == 1 and enemy:getArmor() and self:needToThrowArmor(enemy)))) then
			table.insert(good_enemies, enemy)
		end
	end
	if #good_enemies == 0 and (not self.player:getPile("xingwu"):isEmpty() or not self.player:hasSkill("luoyan")) then return "." end

	local red_avail, black_avail
	local n = self.player:getMark("xingwu")
	if bit32.band(n, 2) == 0 then red_avail = true end
	if bit32.band(n, 1) == 0 then black_avail = true end

	self:sortByKeepValue(cards)
	local xwcard = nil
	local heart = 0
	local to_save = 0
	for _, card in ipairs(cards) do
		if self.player:hasSkill("tianxiang") and card:getSuit() == sgs.Card_Heart and heart < math.min(self.player:getHp(), 2) then
			heart = heart + 1
		elseif isCard("Jink", card, self.player) then
			if self.player:hasSkill("liuli") and self.room:alivePlayerCount() > 2 then
				for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
					if self:canLiuli(self.player, p) then
						xwcard = card
						break
					end
				end
			end
			if not xwcard and self:getCardsNum("Jink") >= 2 then
				xwcard = card
			end
		elseif to_save > self.player:getMaxCards()
				or (not isCard("Peach", card, self.player) and not (self:isWeak() and isCard("Analeptic", card, self.player))) then
			xwcard = card
		else
			to_save = to_save + 1
		end
		if xwcard then
			if (red_avail and xwcard:isRed()) or (black_avail and xwcard:isBlack()) then
				break
			else
				xwcard = nil
				to_save = to_save + 1
			end
		end
	end
	if xwcard then return "$" .. xwcard:getEffectiveId() else return "." end
end

sgs.ai_skill_playerchosen.xingwu = function(self, targets)
	local good_enemies = {}
	for _, enemy in ipairs(self.enemies) do
		if enemy:isMale() then
			table.insert(good_enemies, enemy)
		end
	end
	if #good_enemies == 0 then return targets:first() end

	local getCmpValue = function(enemy)
		local value = 0
		if self:damageIsEffective(enemy) then
			local dmg = enemy:hasArmorEffect("silver_lion") and 1 or 2
			if enemy:getHp() <= dmg then value = 5 else value = value + enemy:getHp() / (enemy:getHp() - dmg) end
			if not sgs.isGoodTarget(enemy, self.enemies, self) then value = value - 2 end
			if self:cantbeHurt(enemy, self.player, dmg) then value = value - 5 end
			if enemy:isLord() then value = value + 2 end
			if enemy:hasArmorEffect("silver_lion") then value = value - 1.5 end
			if self:hasSkills(sgs.exclusive_skill, enemy) then value = value - 1 end
			if self:hasSkills(sgs.masochism_skill, enemy) then value = value - 0.5 end
		end
		if not enemy:getEquips():isEmpty() then
			local len = enemy:getEquips():length()
			if enemy:hasSkills(sgs.lose_equip_skill) then value = value - 0.6 * len end
			if enemy:getArmor() and self:needToThrowArmor() then value = value - 1.5 end
			if enemy:hasArmorEffect("silver_lion") then value = value - 0.5 end

			if enemy:getWeapon() then value = value + 0.8 end
			if enemy:getArmor() then value = value + 1 end
			if enemy:getDefensiveHorse() then value = value + 0.9 end
			if enemy:getOffensiveHorse() then value = value + 0.7 end
			if self:getDangerousCard(enemy) then value = value + 0.3 end
			if self:getValuableCard(enemy) then value = value + 0.15 end
		end
		return value
	end

	local cmp = function(a, b)
		return getCmpValue(a) > getCmpValue(b)
	end
	table.sort(good_enemies, cmp)
	return good_enemies[1]
end

sgs.ai_playerchosen_intention.xingwu = 80

-- 燕语
sgs.ai_skill_cardask["@yanyu-discard"] = function(self, data)
	if self.player:getHandcardNum() < 3 and self.player:getPhase() ~= sgs.Player_Play then
		if self:needToThrowArmor() then return "$" .. self.player:getArmor():getEffectiveId()
		elseif self:needKongcheng(self.player, true) and self.player:getHandcardNum() == 1 then return "$" .. self.player:handCards():first()
		else return "." end
	end
	local current = self.room:getCurrent()
	local cards = sgs.QList2Table(self.player:getHandcards())
	self:sortByKeepValue(cards)
	if current:objectName() == self.player:objectName() then
		local ex_nihilo, savage_assault, archery_attack
		for _, card in ipairs(cards) do
			if card:isKindOf("ExNihilo") then ex_nihilo = card
			elseif card:isKindOf("SavageAssault") and not current:hasSkills("noswuyan|wuyan") then savage_assault = card
			elseif card:isKindOf("ArcheryAttack") and not current:hasSkills("noswuyan|wuyan") then archery_attack = card
			end
		end
		if savage_assault and self:getAoeValue(savage_assault) <= 0 then savage_assault = nil end
		if archery_attack and self:getAoeValue(archery_attack) <= 0 then archery_attack = nil end
		local aoe = archery_attack or savage_assault
		if ex_nihilo then
			for _, card in ipairs(cards) do
				if card:getTypeId() == sgs.Card_TypeTrick and not card:isKindOf("ExNihilo") and card:getEffectiveId() ~= ex_nihilo:getEffectiveId() then
					return "$" .. card:getEffectiveId()
				end
			end
		end
		if self.player:isWounded() then
			local peach
			for _, card in ipairs(cards) do
				if card:isKindOf("Peach") then
					peach = card
					break
				end
			end
			local dummy_use = { isDummy = true }
			self:useCardPeach(peach, dummy_use)
			if dummy_use.card and dummy_use.card:isKindOf("Peach") then
				for _, card in ipairs(cards) do
					if card:getTypeId() == sgs.Card_TypeBasic and card:getEffectiveId() ~= peach:getEffectiveId() then
						return "$" .. card:getEffectiveId()
					end
				end
			end
		end
		if aoe then
			for _, card in ipairs(cards) do
				if card:getTypeId() == sgs.Card_TypeTrick and card:getEffectiveId() ~= aoe:getEffectiveId() then
					return "$" .. card:getEffectiveId()
				end
			end
		end
		if self:getCardsNum("Slash") > 1 then
			for _, card in ipairs(cards) do
				if card:objectName() == "slash" then
					return "$" .. card:getEffectiveId()
				end
			end
		end
	else
		local throw_trick
		local aoe_type
		if getCardsNum("ArcheryAttack", current, self.player) >= 1 and not current:hasSkills("noswuyan|wuyan") then aoe_type = "archery_attack" end
		if getCardsNum("SavageAssault", current, self.player) >= 1 and not current:hasSkills("noswuyan|wuyan") then aoe_type = "savage_assault" end
		if aoe_type then
			local aoe = sgs.Sanguosha:cloneCard(aoe_type)
			if self:getAoeValue(aoe, current) > 0 then throw_trick = true end
		end
		if getCardsNum("ExNihilo", current, self.player) > 0 then throw_trick = true end
		if throw_trick then
			for _, card in ipairs(cards) do
				if card:getTypeId() == sgs.Card_TypeTrick and not isCard("ExNihilo", card, self.player) then
					return "$" .. card:getEffectiveId()
				end
			end
		end
		if self:getCardsNum("Slash") > 1 then
			for _, card in ipairs(cards) do
				if card:objectName() == "slash" then
					return "$" .. card:getEffectiveId()
				end
			end
		end
		if self:getCardsNum("Jink") > 1 then
			for _, card in ipairs(cards) do
				if card:isKindOf("Jink") then
					return "$" .. card:getEffectiveId()
				end
			end
		end
		if self.player:getHp() >= 3 and (self.player:getHandcardNum() > 3 or self:getCardsNum("Peach") > 0) then
			for _, card in ipairs(cards) do
				if card:isKindOf("Slash") then
					return "$" .. card:getEffectiveId()
				end
			end
		end
		if getCardsNum("TrickCard", current, self.player) - getCardsNum("Nullification", current, self.player) > 0 then
			for _, card in ipairs(cards) do
				if card:getTypeId() == sgs.Card_TypeTrick and not isCard("ExNihilo", card, self.player) then
					return "$" .. card:getEffectiveId()
				end
			end
		end
	end
	if self:needToThrowArmor() then return "$" .. self.player:getArmor():getEffectiveId() else return "." end
end

sgs.ai_skill_askforag.yanyu = function(self, card_ids)
	local cards = {}
	for _, id in ipairs(card_ids) do
		table.insert(cards, sgs.Sanguosha:getEngineCard(id))
	end
	self.yanyu_need_player = nil
	local card, player = self:getCardNeedPlayer(cards, true)
	if card and player then
		self.yanyu_need_player = player
		return card:getEffectiveId()
	end
	return -1
end

sgs.ai_skill_playerchosen.yanyu = function(self, targets)
	local only_id = self.player:getMark("YanyuOnlyId") - 1
	if only_id < 0 then
		assert(self.yanyu_need_player ~= nil)
		return self.yanyu_need_player
	else
		local card = sgs.Sanguosha:getEngineCard(only_id)
		if card:getTypeId() == sgs.Card_TypeTrick and not card:isKindOf("Nullification") then
			return self.player
		end
		local cards = { card }
		local c, player = self:getCardNeedPlayer(cards, true)
		return player
	end
end

sgs.ai_playerchosen_intention.yanyu = function(self, from, to)
	if hasManjuanEffect(to) then return end
	local intention = -60
	if self:needKongcheng(to, true) then intention = 10 end
	sgs.updateIntention(from, to, intention)
end

-- 孝德
sgs.ai_skill_invoke.xiaode = function(self, data)
	local round = self:playerGetRound(self.player)
	local xiaode_skill = sgs.ai_skill_choice.huashen(self, table.concat(data:toStringList(), "+"), nil, math.random(1 - round, 7 - round))
	if xiaode_skill then
		sgs.xiaode_choice = xiaode_skill
		return true
	else
		sgs.xiaode_choice = nil
		return false
	end
end

sgs.ai_skill_choice.xiaode = function(self, choices)
	return sgs.xiaode_choice
end

-- 骁果
sgs.ai_skill_cardask["@xiaoguo"] = function(self, data)
	local currentplayer = self.room:getCurrent()

	local has_analeptic, has_slash, has_jink
	for _, acard in sgs.qlist(self.player:getHandcards()) do
		if acard:isKindOf("Analeptic") then has_analeptic = acard
		elseif acard:isKindOf("Slash") then has_slash = acard
		elseif acard:isKindOf("Jink") then has_jink = acard
		end
	end

	local card

	if has_slash then card = has_slash
	elseif has_jink then card = has_jink
	elseif has_analeptic then
		if (getCardsNum("EquipCard", currentplayer, self.player) == 0 and not self:isWeak()) or self:getCardsNum("Analeptic") > 1 then
			card = has_analeptic
		end
	end

	if not card then return "." end
	if self:isFriend(currentplayer) then
		if self:needToThrowArmor(currentplayer) then
			if card:isKindOf("Slash") or (card:isKindOf("Jink") and self:getCardsNum("Jink") > 1) then
				return "$" .. card:getEffectiveId()
			else return "."
			end
		end
	elseif self:isEnemy(currentplayer) then
		if not self:damageIsEffective(currentplayer) then return "." end
		if self:getDamagedEffects(currentplayer) or self:needToLoseHp(currentplayer, self.player) then return "." end
		if self:needToThrowArmor() then return "." end
		if currentplayer:getHp() > 2 and (currentplayer:getHandcardNum() > 2 or currentplayer:getCards("e"):length() > 1)then return "." end
		if currentplayer:getHp() > 1 and (currentplayer:getHandcardNum() > 3 or currentplayer:getCards("e"):length() > 2)then return "." end
		if self:hasSkills(sgs.lose_equip_skill, currentplayer) and currentplayer:getCards("e"):length() > 0 then return "." end
		return "$" .. card:getEffectiveId()
	end
	return "."
end

sgs.ai_choicemade_filter.cardResponded["@xiaoguo"] = function(self, player, promptlist)
	if promptlist[#promptlist] ~= "_nil_" then
		local current = self.room:getCurrent()
		if not current then return end
		local intention = 10
		if self:hasSkills(sgs.lose_equip_skill, current) and current:getCards("e"):length() > 0 then intention = 0 end
		if self:needToThrowArmor(current) then return end
		sgs.updateIntention(player, current, intention)
	end
end

sgs.ai_skill_cardask["@xiaoguo-discard"] = function(self, data)
	local yuejin = self.room:findPlayerBySkillName("xiaoguo")
	local player = self.player

	if self:needToThrowArmor() then
		return "$" .. player:getArmor():getEffectiveId()
	end

	if not self:damageIsEffective(player, sgs.DamageStruct_Normal, yuejin) then
		return "."
	end
	if self:getDamagedEffects(self.player, yuejin) then
		return "."
	end
	if self:needToLoseHp(player, yuejin) then
		return "."
	end

	local card_id
	if self:hasSkills(sgs.lose_equip_skill, player) then
		if player:getWeapon() then card_id = player:getWeapon():getId()
		elseif player:getOffensiveHorse() then card_id = player:getOffensiveHorse():getId()
		elseif player:getArmor() then card_id = player:getArmor():getId()
		elseif player:getDefensiveHorse() then card_id = player:getDefensiveHorse():getId()
		end
	end

	if not card_id then
		for _, card in sgs.qlist(player:getCards("h")) do
			if card:isKindOf("EquipCard") then
				card_id = card:getEffectiveId()
				break
			end
		end
	end

	if not card_id then
		if player:getWeapon() then card_id = player:getWeapon():getId()
		elseif player:getOffensiveHorse() then card_id = player:getOffensiveHorse():getId()
		elseif self:isWeak(player) and player:getArmor() then card_id = player:getArmor():getId()
		elseif self:isWeak(player) and player:getDefensiveHorse() then card_id = player:getDefensiveHorse():getId()
		end
	end

	if not card_id then return "." else return "$" .. card_id end
end

sgs.ai_cardneed.xiaoguo = function(to, card)
	return getKnownCard(to, global_room:getCurrent(), "BasicCard", true) == 0 and card:getTypeId() == sgs.Card_Basic
end

-- 咒缚
function getNextJudgeReason(self, player)
	if self:playerGetRound(player) > 2 then
		if player:hasSkills("ganglie|vsganglie") then return end
		local caiwenji = self.room:findPlayerBySkillName("beige")
		if caiwenji and caiwenji:canDiscard(caiwenji, "he") and self:isFriend(caiwenji, player) then return end
		if player:hasArmorEffect("eight_diagram") or player:hasSkill("bazhen") then
			if self:playerGetRound(player) > 3 and self:isEnemy(player) then return "EightDiagram"
			else return end
		end
	end
	if self:isFriend(player) and player:hasSkill("luoshen") then return "luoshen" end
	if not player:getJudgingArea():isEmpty() and not player:containsTrick("YanxiaoCard") then
		return player:getJudgingArea():last():objectName()
	end
	if player:hasSkill("qianxi") then return "qianxi" end
	if player:hasSkill("nosmiji") and player:getLostHp() > 0 then return "nosmiji" end
	if player:hasSkill("tuntian") then return "tuntian" end
	if player:hasSkill("tieji") then return "tieji" end
	if player:hasSkill("nosqianxi") then return "nosqianxi" end
	if player:hasSkill("caizhaoji_hujia") then return "caizhaoji_hujia" end
end

local zhoufu_skill = {}
zhoufu_skill.name = "zhoufu"
table.insert(sgs.ai_skills, zhoufu_skill)
zhoufu_skill.getTurnUseCard = function(self)
	if self.player:hasUsed("ZhoufuCard") or self.player:isKongcheng() then return end
	return sgs.Card_Parse("@ZhoufuCard=.")
end

sgs.ai_skill_use_func.ZhoufuCard = function(card, use, self)
	local cards = {}
	for _, card in sgs.qlist(self.player:getHandcards()) do
		table.insert(cards, sgs.Sanguosha:getEngineCard(card:getEffectiveId()))
	end
	self:sortByKeepValue(cards)
	self:sort(self.friends_noself)
	local zhenji
	for _, friend in ipairs(self.friends_noself) do
		if friend:getPile("incantation"):length() > 0 then continue end
		local reason = getNextJudgeReason(self, friend)
		if reason then
			if reason == "luoshen" then
				zhenji = friend
			elseif reason == "indulgence" then
				for _, card in ipairs(cards) do
					if card:getSuit() == sgs.Card_Heart or (friend:hasSkill("hongyan") and card:getSuit() == sgs.Card_Spade)
						and (friend:hasSkill("tiandu") or not self:isValuableCard(card)) then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(friend) end
						return
					end
				end
			elseif reason == "supply_shortage" then
				for _, card in ipairs(cards) do
					if card:getSuit() == sgs.Card_Club and (friend:hasSkill("tiandu") or not self:isValuableCard(card)) then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(friend) end
						return
					end
				end
			elseif reason == "lightning" and not friend:hasSkills("hongyan|wuyan") then
				for _, card in ipairs(cards) do
					if (card:getSuit() ~= sgs.Card_Spade or card:getNumber() == 1 or card:getNumber() > 9)
						and (friend:hasSkill("tiandu") or not self:isValuableCard(card)) then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(friend) end
						return
					end
				end
			elseif reason == "nosmiji" then
				for _, card in ipairs(cards) do
					if card:getSuit() == sgs.Card_Club or (card:getSuit() == sgs.Card_Spade and not friend:hasSkill("hongyan")) then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(friend) end
						return
					end
				end
			elseif reason == "nosqianxi" or reason == "tuntian" then
				for _, card in ipairs(cards) do
					if (card:getSuit() ~= sgs.Card_Heart and not (card:getSuit() == sgs.Card_Spade and friend:hasSkill("hongyan")))
						and (friend:hasSkill("tiandu") or not self:isValuableCard(card)) then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(friend) end
						return
					end
				end
			elseif reason == "tieji" or reason == "caizhaoji_hujia" then
				for _, card in ipairs(cards) do
					if (card:isRed() or card:getSuit() == sgs.Card_Spade and friend:hasSkill("hongyan"))
						and (friend:hasSkill("tiandu") or not self:isValuableCard(card)) then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(friend) end
						return
					end
				end
			end
		end
	end
	if zhenji then
		for _, card in ipairs(cards) do
			if card:isBlack() and not (zhenji:hasSkill("hongyan") and card:getSuit() == sgs.Card_Spade) then
				use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
				if use.to then use.to:append(zhenji) end
				return
			end
		end
	end
	self:sort(self.enemies)
	for _, enemy in ipairs(self.enemies) do
		if enemy:getPile("incantation"):length() > 0 then continue end
		local reason = getNextJudgeReason(self, enemy)
		if not enemy:hasSkill("tiandu") and reason then
			if reason == "indulgence" then
				for _, card in ipairs(cards) do
					if not (card:getSuit() == sgs.Card_Heart or (enemy:hasSkill("hongyan") and card:getSuit() == sgs.Card_Spade))
						and not self:isValuableCard(card) then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(enemy) end
						return
					end
				end
			elseif reason == "supply_shortage" then
				for _, card in ipairs(cards) do
					if card:getSuit() ~= sgs.Card_Club and not self:isValuableCard(card) then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(enemy) end
						return
					end
				end
			elseif reason == "lightning" and not enemy:hasSkills("hongyan|wuyan") then
				for _, card in ipairs(cards) do
					if card:getSuit() == sgs.Card_Spade and card:getNumber() >= 2 and card:getNumber() <= 9 then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(enemy) end
						return
					end
				end
			elseif reason == "nosmiji" then
				for _, card in ipairs(cards) do
					if card:isRed() or card:getSuit() == sgs.Card_Spade and enemy:hasSkill("hongyan") then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(enemy) end
						return
					end
				end
			elseif reason == "nosqianxi" or reason == "tuntian" then
				for _, card in ipairs(cards) do
					if (card:getSuit() == sgs.Card_Heart or card:getSuit() == sgs.Card_Spade and enemy:hasSkill("hongyan"))
						and not self:isValuableCard(card) then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(enemy) end
						return
					end
				end
			elseif reason == "tieji" or reason == "caizhaoji_hujia" then
				for _, card in ipairs(cards) do
					if (card:getSuit() == sgs.Card_Club or (card:getSuit() == sgs.Card_Spade and not enemy:hasSkill("hongyan")))
						and not self:isValuableCard(card) then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(enemy) end
						return
					end
				end
			end
		end
	end

	local has_indulgence, has_supplyshortage
	local friend
	for _, p in ipairs(self.friends) do
		if getKnownCard(p, self.player, "Indulgence", true, "he") > 0 then
			has_indulgence = true
			friend = p
			break
		end
		if getKnownCard(p, self.player, "SupplySortage", true, "he") > 0 then
			has_supplyshortage = true
			friend = p
			break
		end
	end
	if has_indulgence then
		local indulgence = sgs.Sanguosha:cloneCard("indulgence")
		for _, enemy in ipairs(self.enemies) do
			if enemy:getPile("incantation"):length() > 0 then continue end
			if self:hasTrickEffective(indulgence, enemy, friend) and self:playerGetRound(friend) < self:playerGetRound(enemy) and not self:willSkipPlayPhase(enemy) then
				for _, card in ipairs(cards) do
					if not (card:getSuit() == sgs.Card_Heart or (enemy:hasSkill("hongyan") and card:getSuit() == sgs.Card_Spade))
						and not self:isValuableCard(card) then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(enemy) end
						return
					end
				end
			end
		end
	elseif has_supplyshortage then
		local supplyshortage = sgs.Sanguosha:cloneCard("supply_shortage")
		local distance = self:getDistanceLimit(supplyshortage, friend)
		for _, enemy in ipairs(self.enemies) do
			if enemy:getPile("incantation"):length() > 0 then continue end
			if self:hasTrickEffective(supplyshortage, enemy, friend) and self:playerGetRound(friend) < self:playerGetRound(enemy)
				and not self:willSkipDrawPhase(enemy) and friend:distanceTo(enemy) <= distance then
				for _, card in ipairs(cards) do
					if card:getSuit() ~= sgs.Card_Club and not self:isValuableCard(card) then
						use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
						if use.to then use.to:append(enemy) end
						return
					end
				end
			end
		end
	end

	for _, target in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		if target:getPile("incantation"):length() > 0 then continue end
		if self:hasEightDiagramEffect(target) then
			for _, card in ipairs(cards) do
				if (card:isRed() and self:isFriend(target)) or (card:isBlack() and self:isEnemy(target)) and not self:isValuableCard(card) then
					use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
					if use.to then use.to:append(target) end
					return
				end
			end
		end
	end

	if self:getOverflow() > 0 then
		for _, target in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		if target:getPile("incantation"):length() > 0 then continue end
			for _, card in ipairs(cards) do
				if not self:isValuableCard(card) and math.random() > 0.5 then
					use.card = sgs.Card_Parse("@ZhoufuCard=" .. card:getEffectiveId())
					if use.to then use.to:append(target) end
					return
				end
			end
		end
	end

end

sgs.ai_card_intention.ZhoufuCard = 0
sgs.ai_use_value.ZhoufuCard = 2
sgs.ai_use_priority.ZhoufuCard = sgs.ai_use_priority.Indulgence - 0.1

-- 影兵
sgs.ai_skill_invoke.yingbing = sgs.ai_skill_invoke.biyue

--慷慨
local function getKangkaiCard(self, target, data)
	local use = data:toCardUse()
	local weapon, armor, def_horse, off_horse = {}, {}, {}, {}
	for _, card in sgs.qlist(self.player:getHandcards()) do
		if card:isKindOf("Weapon") then table.insert(weapon, card)
		elseif card:isKindOf("Armor") then table.insert(armor, card)
		elseif card:isKindOf("DefensiveHorse") then table.insert(def_horse, card)
		elseif card:isKindOf("OffensiveHorse") then table.insert(off_horse, card)
		end
	end
	if #armor > 0 then
		for _, card in ipairs(armor) do
			if ((not target:getArmor() and not target:hasSkills("bazhen|yizhong"))
				or (target:getArmor() and self:evaluateArmor(card, target) >= self:evaluateArmor(target:getArmor(), target)))
				and not (card:isKindOf("Vine") and use.card:isKindOf("FireSlash") and self:slashIsEffective(use.card, target, use.from)) then
				return card:getEffectiveId()
			end
		end
	end
	if self:needToThrowArmor()
		and ((not target:getArmor() and not target:hasSkills("bazhen|yizhong"))
			or (target:getArmor() and self:evaluateArmor(self.player:getArmor(), target) >= self:evaluateArmor(target:getArmor(), target)))
		and not (self.player:getArmor():isKindOf("Vine") and use.card:isKindOf("FireSlash") and self:slashIsEffective(use.card, target, use.from)) then
		return self.player:getArmor():getEffectiveId()
	end
	if #def_horse > 0 then return def_horse[1]:getEffectiveId() end
	if #weapon > 0 then
		for _, card in ipairs(weapon) do
			if not target:getWeapon()
				or (self:evaluateArmor(card, target) >= self:evaluateArmor(target:getWeapon(), target)) then
				return card:getEffectiveId()
			end
		end
	end
	if self.player:getWeapon() and self:evaluateWeapon(self.player:getWeapon()) < 5
		and (not target:getArmor()
			or (self:evaluateArmor(self.player:getWeapon(), target) >= self:evaluateArmor(target:getWeapon(), target))) then
		return self.player:getWeapon():getEffectiveId()
	end
	if #off_horse > 0 then return off_horse[1]:getEffectiveId() end
	if self.player:getOffensiveHorse()
		and ((self.player:getWeapon() and not self.player:getWeapon():isKindOf("Crossbow")) or self.player:hasSkills("mashu|tuntian")) then
		return self.player:getOffensiveHorse():getEffectiveId()
	end
end

sgs.ai_skill_invoke.kangkai = function(self, data)
	self.kangkai_give_id = nil
	if hasManjuanEffect(self.player) then return false end
	local target = data:toPlayer()
	if not target then return false end
	if target:objectName() == self.player:objectName() then
		return true
	elseif not self:isFriend(target) then
		return hasManjuanEffect(target)
	else
		local id = getKangkaiCard(self, target, self.player:getTag("KangkaiSlash"))
		if id then return true else return not self:needKongcheng(target, true) end
	end
end

sgs.ai_skill_cardask["@kangkai_give"] = function(self, data, pattern, target)
	if self:isFriend(target) then
		local id = getKangkaiCard(self, target, data)
		if id then return "$" .. id end
		if self:getCardsNum("Jink") > 1 then
			for _, card in sgs.qlist(self.player:getHandcards()) do
				if isCard("Jink", card, target) then return "$" .. card:getEffectiveId() end
			end
		end
		for _, card in sgs.qlist(self.player:getHandcards()) do
			if not self:isValuableCard(card) then return "$" .. card:getEffectiveId() end
		end
	else
		local to_discard = self:askForDiscard("dummyreason", 1, 1, false, true)
		if #to_discard > 0 then return "$" .. to_discard[1] end
	end
end

sgs.ai_skill_invoke.kangkai_use = function(self, data)
	local use = self.player:getTag("KangkaiSlash"):toCardUse()
	local card = self.player:getTag("KangkaiCard"):toCard()
	if not use.card or not card then return false end
	if card:isKindOf("Vine") and use.card:isKindOf("FireSlash") and self:slashIsEffective(use.card, self.player, use.from) then return false end
	if ((card:isKindOf("DefensiveHorse") and self.player:getDefensiveHorse())
		or (card:isKindOf("OffensiveHorse") and (self.player:getOffensiveHorse() or (self.player:hasSkill("drmashu") and self.player:getDefensiveHorse()))))
		and not self.player:hasSkills(sgs.lose_equip_skill) then
		return false
	end
	if card:isKindOf("Armor")
		and ((self.player:hasSkills("bazhen|yizhong") and not self.player:getArmor())
			or (self.player:getArmor() and self:evaluateArmor(card) < self:evaluateArmor(self.player:getArmor()))) then return false end
	if card:isKindOf("Weanpon") and (self.player:getWeapon() and self:evaluateArmor(card) < self:evaluateArmor(self.player:getWeapon())) then return false end
	return true
end

-- 弘援
sgs.ai_skill_invoke.hongyuan = function(self, data)
	local count = 0
	for i = 1, #self.friends_noself do
		if self:needKongcheng(self.friends_noself[i], true) or self.friends_noself[i]:hasSkill("manjuan") then
		else
			count = count + 1
		end
		if count == 2 then return true end
	end
	return false
end

sgs.ai_skill_use["@@hongyuan"] = function(self, prompt)
	self:sort(self.friends_noself, "handcard")
	local first_index, second_index
	for i = 1, #self.friends_noself do
		if self:needKongcheng(self.friends_noself[i]) and self.friends_noself[i]:getHandcardNum() == 0
			or self.friends_noself[i]:hasSkill("manjuan") then
		else
			if not first_index then
				first_index = i
			else
				second_index = i
			end
		end
		if second_index then break end
	end

	if first_index and not second_index then
		local others = self.room:getOtherPlayers(self.player)
		for _, other in sgs.qlist(others) do
			if (not self:isFriend(other) and (self:needKongcheng(other) and other:getHandcardNum() == 0 or other:hasSkill("manjuan"))) and
				self.friends_noself[first_index]:objectName() ~= other:objectName() then
				return ("@HongyuanCard=.->%s+%s"):format(self.friends_noself[first_index]:objectName(), other:objectName())
			end
		end
	end

	if not second_index then return "." end

	local first = self.friends_noself[first_index]:objectName()
	local second = self.friends_noself[second_index]:objectName()
	return ("@HongyuanCard=.->%s+%s"):format(first, second)
end

sgs.ai_card_intention.HongyuanCard = -70

-- 缓释
sgs.ai_skill_cardask["@huanshi-card"] = function(self, data)
	local judge = data:toJudge()

	if self:needRetrial(judge) then
		local cards = sgs.QList2Table(self.player:getCards("he"))
		for _, id in sgs.qlist(self.player:getPile("wooden_ox")) do
			cards:prepend(sgs.Sanguosha:getCard(id))
		end
		local card_id = self:getRetrialCardId(cards, judge)
		if card_id ~= -1 then
			return "$" .. card_id
		end
	end

	return "."
end

sgs.ai_skill_invoke.huanshi = function(self, data)
	local judge = data:toJudge()

	if self:needRetrial(judge) then
		local cards = sgs.QList2Table(self.player:getCards("he"))
		if self:isFriend(judge.who) then
			local card_id = self:getRetrialCardId(cards, judge)
			if card_id ~= -1 then return true end
		elseif self:isEnemy(judge.who) then
			for _, card in ipairs(cards) do
				if judge:isGood(card) or self:isValuableCard(card) then return false end
			end
			return true
		end
	end
	return false
end

sgs.ai_skill_askforag.huanshi = function(self, card_ids)
	local cards = {}
	for _, id in ipairs(card_ids) do
		table.insert(cards, sgs.Sanguosha:getCard(id))
	end
	local judge = self.player:getTag("HuanshiJudge"):toJudge()
	local zhugejin = self.room:findPlayerBySkillName("huanshi")

	local cmp = function(a, b)
		local a_keep_value, b_keep_value = sgs.ai_keep_value[a:getClassName()] or 0, sgs.ai_keep_value[b:getClassName()] or 0
		a_keep_value = a_keep_value + a:getNumber() / 100
		b_keep_value = b_keep_value + b:getNumber() / 100
		if zhugejin and zhugejin:hasSkill("mingzhe") then
			if a:isRed() then a_keep_value = a_keep_value - 0.3 end
			if b:isRed() then b_keep_value = b_keep_value - 0.3 end
		end
		return a_keep_value < b_keep_value
	end

	local card_id = self:getRetrialCardId(cards, judge, false)
	if card_id ~= -1 then return card_id end
	if zhugejin and not self:isEnemy(zhugejin) then
		local valueless = {}
		for _, card in ipairs(cards) do
			if not self:isValuableCard(card, zhugejin) then table.insert(valueless, card) end
		end
		if #valueless == 0 then valueless = cards end
		table.sort(valueless, cmp)
		return valueless[1]:getEffectiveId()
	else
		for _, card in ipairs(cards) do
			if judge:isGood(card) then return card:getEffectiveId() end
		end
		local valuable = {}
		for _, card in ipairs(cards) do
			if self:isValuableCard(card, zhugejin) then table.insert(valuable, card) end
		end
		if #valuable == 0 then valuable = cards end
		table.sort(valuable, cmp)
		return valuable[#valuable]:getEffectiveId()
	end
	return -1
end

function sgs.ai_cardneed.huanshi(to, card, self)
	for _, player in ipairs(self.friends) do
		if self:getFinalRetrial(to) == 1 then
			if self:willSkipDrawPhase(player) then
				return card:getSuit() == sgs.Card_Club and not self:hasSuit("club", true, to)
			end
			if self:willSkipPlayPhase(player) then
				return card:getSuit() == sgs.Card_Heart and not self:hasSuit("heart", true, to)
			end
		end
	end
end

sgs.huanshi_suit_value = {
	heart = 3.9,
	diamond = 3.4,
	club = 3.9,
	spade = 3.5
}

-- 明哲
function sgs.ai_cardneed.mingzhe(to, card, self)
	return card:isRed() and getKnownCard(to, self.player, "red", false) < 2
end

sgs.mingzhe_suit_value = {
	heart = 4.0,
	diamond = 4.0
}

-- 甚贤
sgs.ai_skill_invoke.shenxian = sgs.ai_skill_invoke.biyue

-- 枪舞
local qiangwu_skill = {}
qiangwu_skill.name = "qiangwu"
table.insert(sgs.ai_skills, qiangwu_skill)
qiangwu_skill.getTurnUseCard = function(self)
	if self.player:hasUsed("QiangwuCard") then return end
	return sgs.Card_Parse("@QiangwuCard=.")
end

sgs.ai_skill_use_func.QiangwuCard = function(card, use, self)
	if self.player:hasUsed("QiangwuCard") then return end
	use.card = card
end

sgs.ai_use_value.QiangwuCard = 3

sgs.ai_use_priority.QiangwuCard = 11

sgs.ai_cardneed.qiangwu = sgs.ai_cardneed.paoxiao

-- 狂斧
sgs.ai_skill_invoke.kuangfu = function(self, data)
	local damage = data:toDamage()
	if self:hasSkills(sgs.lose_equip_skill, damage.to) then
		return self:isFriend(damage.to) and not self:isWeak(damage.to)
	end
	local benefit = (damage.to:getCards("e"):length() == 1 and damage.to:getArmor() and self:needToThrowArmor(damage.to))
	if self:isFriend(damage.to) then return benefit end
	return not benefit
end

sgs.ai_skill_choice.kuangfu_equip = function(self, choices, data)
	local who = data:toPlayer()
	if self:isFriend(who) then
		if choices:match("1") and self:needToThrowArmor(who) then return "1" end
		if choices:match("1") and self:evaluateArmor(who:getArmor(), who) < -5 then return "1" end
		if self:hasSkills(sgs.lose_equip_skill, who) and self:isWeak(who) then
			if choices:match("0") then return "0" end
			if choices:match("3") then return "3" end
		end
	else
		local dangerous = self:getDangerousCard(who)
		if dangerous then
			local card = sgs.Sanguosha:getCard(dangerous)
			if card:isKindOf("Weapon") and choices:match("0") then return "0"
			elseif card:isKindOf("Armor") and choices:match("1") then return "1"
			elseif card:isKindOf("DefensiveHorse") and choices:match("2") then return "2"
			elseif card:isKindOf("OffensiveHorse") and choices:match("3") then return "3"
			end
		end
		if choices:match("1") and who:hasArmorEffect("eight_diagram") and not self:needToThrowArmor(who) then return "1" end
		if self:hasSkills("jijiu|beige|mingce|weimu|qingcheng", who) and not self:doNotDiscard(who, "e", false, 1, reason) then
			if choices:match("2") then return "2" end
			if choices:match("1") and who:getArmor() and not self:needToThrowArmor(who) then return "1" end
			if choices:match("3") and (not who:hasSkill("jijiu") or who:getOffensiveHorse():isRed()) then return "3" end
			if choices:match("0") and (not who:hasSkill("jijiu") or who:getWeapon():isRed()) then return "0" end
		end
		local valuable = self:getValuableCard(who)
		if valuable then
			local card = sgs.Sanguosha:getCard(valuable)
			if card:isKindOf("Weapon") and choices:match("0") then return "0"
			elseif card:isKindOf("Armor") and choices:match("1") then return "1"
			elseif card:isKindOf("DefensiveHorse") and choices:match("2") then return "2"
			elseif card:isKindOf("OffensiveHorse") and choices:match("3") then return "3"
			end
		end
		if not self:doNotDiscard(who, "e") then
			if choices:match("3") then return "3" end
			if choices:match("1") then return "1" end
			if choices:match("2") then return "2" end
			if choices:match("0") then return "0" end
		end
	end
end

sgs.ai_skill_choice.kuangfu = function(self, choices)
	return "move"
end

sgs.ai_cardneed.kuangfu = sgs.ai_cardneed.lieren

-- 引兵
sgs.ai_skill_use["@@yinbing"] = function(self, prompt)
	--手牌
	local otherNum = self.player:getHandcardNum() - self:getCardsNum("BasicCard")
	if otherNum == 0 then return "." end

	local slashNum = self:getCardsNum("Slash")
	local jinkNum = self:getCardsNum("Jink")
	local enemyNum = #self.enemies
	local friendNum = #self.friends

	local value = 0
	if otherNum > 1 then value = value + 0.3 end
	for _,card in sgs.qlist(self.player:getHandcards()) do
		if card:isKindOf("EquipCard") then value = value + 1 end
	end
	if otherNum == 1 and self:getCardsNum("Nullification") == 1 then value = value - 0.2 end

	--已有引兵
	if self.player:getPile("yinbing"):length() > 0 then value = value + 0.2 end

	--双将【空城】
	if self:needKongcheng() and self.player:getHandcardNum() == 1 then value = value + 3 end

	if enemyNum == 1 then value = value + 0.7 end
	if friendNum - enemyNum > 0 then value = value + 0.2 else value = value - 0.3 end
	local slash = sgs.Sanguosha:cloneCard("slash")
	--关于 【杀】和【决斗】
	if slashNum == 0 then value = value - 0.1 end
	if jinkNum == 0 then value = value - 0.5 end
	if jinkNum == 1 then value = value + 0.2 end
	if jinkNum > 1 then value = value + 0.5 end
	if self.player:getArmor() and self.player:getArmor():isKindOf("EightDiagram") then value = value + 0.4 end
	for _,enemy in ipairs(self.enemies) do
		if enemy:canSlash(self.player, slash) and self:slashIsEffective(slash, self.player, enemy) and (enemy:inMyAttackRange(self.player) or enemy:hasSkills("zhuhai|shensu")) then
			if ((enemy:getWeapon() and enemy:getWeapon():isKindOf("Crossbow")) or enemy:hasSkills("paoxiao|tianyi|xianzhen|jiangchi|fuhun|gongqi|longyin|qiangwu")) and enemy:getHandcardNum() > 1 then
				value = value - 0.2
			end
			if enemy:hasSkills("tieqi|wushuang|yijue|liegong|mengjin|qianxi") then
				value = value - 0.2
			end
			value = value - 0.2
		end
		if enemy:hasSkills("lijian|shuangxiong|mingce|mizhao") then
			value = value - 0.2
		end
	end
	--肉盾
	local yuanshu = self.room:findPlayerBySkillName("tongji")
	if yuanshu and yuanshu:getHandcardNum() > yuanshu:getHp() then value = value + 0.4 end
	for _,friend in ipairs(self.friends) do
		if friend:hasSkills("fangquan|zhenwei|kangkai") then value = value + 0.4 end
	end

	if value < 0 then return "." end

	local card_ids = {}
	local nulId
	for _,card in sgs.qlist(self.player:getHandcards()) do
		if not card:isKindOf("BasicCard") then
			if card:isKindOf("Nullification") then
				nulId = card:getEffectiveId()
			else
				table.insert(card_ids, card:getEffectiveId())
			end
		end
	end
	if nulId and #card_ids == 0 then
		table.insert(card_ids, nulId)
	end
	return "@YinbingCard=" .. table.concat(card_ids, "+") .. "->."
end

sgs.yinbing_keep_value = {
	EquipCard = 5,
	TrickCard = 4
}

-- 绝地
sgs.ai_skill_invoke.juedi = function(self, data)
	for _, friend in ipairs(self.friends_noself) do
		if friend:getLostHp() > 0 then return true end
	end
	if self:isWeak() then return true end
	return false
end

sgs.ai_skill_playerchosen.juedi = function(self, targets)
	targets = sgs.QList2Table(targets)
	self:sort(targets, "defense")
	for _,p in ipairs(targets) do
		if self:isFriend(p) then return p end
	end
	return
end

-- 短兵
sgs.ai_cardneed.duanbing = sgs.ai_cardneed.lieren

-- 奋迅
local fenxun_skill = {}
fenxun_skill.name = "fenxun"
table.insert(sgs.ai_skills, fenxun_skill)
fenxun_skill.getTurnUseCard = function(self)
	if self.player:hasUsed("FenxunCard") then return end
	if #self.enemies == 0 then return end
	if self:needBear() then return end
	if not self.player:isNude() then
		local card_id
		local slashcount = self:getCardsNum("Slash")
		local jinkcount = self:getCardsNum("Jink")
		local cards = self.player:getHandcards()
		cards = sgs.QList2Table(cards)
		self:sortByKeepValue(cards)

		if self:needToThrowArmor() then
			return sgs.Card_Parse("@FenxunCard=" .. self.player:getArmor():getId())
		elseif self.player:getHandcardNum() > 0 then
			local lightning = self:getCard("Lightning")
			if lightning and not self:willUseLightning(lightning) then
				card_id = lightning:getEffectiveId()
			else
				for _, acard in ipairs(cards) do
					if (acard:isKindOf("AmazingGrace") or acard:isKindOf("EquipCard")) then
						card_id = acard:getEffectiveId()
						break
					end
				end
			end
			if not card_id and jinkcount > 1 then
				for _, acard in ipairs(cards) do
					if acard:isKindOf("Jink") then
						card_id = acard:getEffectiveId()
						break
					end
				end
			end
			if not card_id and slashcount > 1 then
				for _, acard in ipairs(cards) do
					if acard:isKindOf("Slash") then
						slashcount = slashcount - 1
						card_id = acard:getEffectiveId()
						break
					end
				end
			end
		end

		if not card_id and self.player:getWeapon() then
			card_id = self.player:getWeapon():getId()
		end

		if not card_id then
			for _, acard in ipairs(cards) do
				if (acard:isKindOf("AmazingGrace") or acard:isKindOf("EquipCard") or acard:isKindOf("BasicCard"))
					and not isCard("Peach", acard, self.player) and not isCard("Slash", acard, self.player) then
					card_id = acard:getEffectiveId()
					break
				end
			end
		end

		if slashcount > 0 and card_id then
			return sgs.Card_Parse("@FenxunCard=" .. card_id)
		end
	end
	return nil
end

sgs.ai_skill_use_func.FenxunCard = function(card, use, self)
	self:sort(self.enemies, "defense")
	local target
	for _, slash in ipairs(self:getCards("Slash")) do
		if slash:getEffectiveId() ~= card:getEffectiveId() then
			local target_num, hastarget = 0
			for _, enemy in ipairs(self.enemies) do
				if not self:slashProhibit(slash, enemy) and self.player:canSlash(enemy, slash, false) and sgs.isGoodTarget(enemy, self.enemies, self, true) then
					if self.player:distanceTo(enemy) > 1 and not target then target = enemy
					elseif self.player:distanceTo(enemy) == 1 then
						hastarget = true
					end
					if self.player:inMyAttackRange(enemy) then
						target_num = target_num + 1
					end
				end
			end
			if hastarget and target_num >= 2 then return end
		end
	end
	if target and self:getCardsNum("Slash") > 0 then
		use.card = card
		if use.to then
			use.to:append(target)
		end
	end
end

sgs.ai_use_value.FenxunCard = 5.5
sgs.ai_use_priority.FenxunCard = 8
sgs.ai_card_intention.FenxunCard = 50

-- 鸩毒
local function will_discard_zhendu(self)
	local current = self.room:getCurrent()
	local need_damage = self:getDamagedEffects(current, self.player) or self:needToLoseHp(current, self.player)
	if self:isFriend(current) then
		if current:getMark("drank") > 0 and not need_damage then return -1 end
		if (getKnownCard(current, self.player, "Slash") > 0 or (getCardsNum("Slash", current, self.player) >= 1 and current:getHandcardNum() >= 2))
			and (not self:damageIsEffective(current, nil, self.player) or current:getHp() > 2 or (getCardsNum("Peach", current, self.player) > 1 and not self:isWeak(current))) then
			local slash = sgs.Sanguosha:cloneCard("slash")
			local trend = 3
			if current:hasWeapon("Axe") then trend = trend - 1
			elseif current:hasSkills("liegong|tieqi|wushuang|niaoxiang") then trend = trend - 0.4 end
			for _, enemy in ipairs(self.enemies) do
				if ((enemy:getHp() < 3 and enemy:getHandcardNum() < 3) or (enemy:getHandcardNum() < 2)) and current:canSlash(enemy) and not self:slashProhibit(slash, enemy, current)
					and self:slashIsEffective(slash, enemy, current) and sgs.isGoodTarget(enemy, self.enemies, self, true) then
					return trend
				end
			end
		end
		if need_damage then return 3 end
	elseif self:isEnemy(current) then
		if current:getHp() == 1 then return 1 end
		if need_damage or current:getHandcardNum() >= 2 then return -1 end
		if getKnownCard(current, self.player, "Slash") == 0 and getCardsNum("Slash", current, self.player) < 0.5 then return 3.5 end
	end
	return -1
end

sgs.ai_skill_cardask["@zhendu-discard"] = function(self, data)
	local discard_trend = will_discard_zhendu(self)
	if discard_trend <= 0 then return "." end
	if self.player:getHandcardNum() + math.random(1, 100) / 100 >= discard_trend then
		local cards = sgs.QList2Table(self.player:getHandcards())
		self:sortByKeepValue(cards)
		for _, card in ipairs(cards) do
			if not self:isValuableCard(card, self.player) then return "$" .. card:getEffectiveId() end
		end
	end
	return "."
end

-- 戚乱
sgs.ai_skill_invoke.qiluan = sgs.ai_skill_invoke.biyue

-- 魅步
sgs.ai_skill_invoke.meibu = function (self, data)
	local target = self.room:getCurrent()
	if self:isFriend(target) then
		--锦囊不如杀重要的情况
		local trick = sgs.Sanguosha:cloneCard("nullification")
		if target:hasSkill("wumou") or target:isJilei(trick) then return true end
		local slash = sgs.Sanguosha:cloneCard("Slash")
		dummy_use = {isDummy = true, from = target, to = sgs.SPlayerList()}
		self:useBasicCard(slash, dummy_use)
		if target:getWeapon() and target:getWeapon():isKindOf("Crossbow") and not dummy_use.to:isEmpty() then return true end
		if target:hasSkills("paoxiao|tianyi|xianzhen|jiangchi|fuhun|qiangwu") and not self:isWeak(target) and not dummy_use.to:isEmpty() then return true end
	else
		local slash2 = sgs.Sanguosha:cloneCard("Slash")
		if target:isJilei(slash2) then return true end
		if target:getWeapon() and target:getWeapon():isKindOf("blade") then return false end
		if target:hasSkills("paoxiao|tianyi|xianzhen|jiangchi|fuhun|qiangwu") or (target:getWeapon() and target:getWeapon():isKindOf("Crossbow")) then return false end
		if target:hasSkills("wumou|gongqi") then return false end
		if target:hasSkills("guose|qixi|duanliang|luanji") and target:getHandcardNum() > 1 then return true end
		if target:hasSkills("shuangxiong") and not self:isWeak(target) then return true end
		if not self:slashIsEffective(slash2, self.player, target) and not self:isWeak() then return true end
		if self.player:getArmor() and self.player:getArmor():isKindOf("Vine") and not self:isWeak() then return true end
		if self.player:getArmor() and not self:isWeak() and self:getCardsNum("Jink") > 0 then return true end
	end
	return false
end

-- 穆穆
sgs.ai_skill_choice.mumu = function(self, choices)
	local armorPlayersF = {}
	local weaponPlayersE = {}
	local armorPlayersE = {}

	for _,p in ipairs(self.friends_noself) do
		if p:getArmor() and p:objectName() ~= self.player:objectName() then
			table.insert(armorPlayersF, p)
		end
	end
	for _,p in ipairs(self.enemies) do
		if p:getWeapon() and self.player:canDiscard(p, p:getWeapon():getEffectiveId()) then
			table.insert(weaponPlayersE, p)
		end
		if p:getArmor() and p:objectName() ~= self.player:objectName() then
			table.insert(armorPlayersE, p)
		end
	end

	self.player:setFlags("mumu_armor")
	if #armorPlayersF > 0 then
		for _,friend in ipairs(armorPlayersF) do
			if (friend:getArmor():isKindOf("Vine") and not self.player:getArmor() and not friend:hasSkills("kongcheng|zhiji")) or (friend:getArmor():isKindOf("SilverLion") and friend:getLostHp() > 0) then
				return "armor"
			end
		end
	end

	if #armorPlayersE > 0 then
		if not self.player:getArmor() then return "armor" end
		if self.player:getArmor() and self.player:getArmor():isKindOf("SilverLion") and self.player:getLostHp() > 0 then return "armor" end
		for _,enemy in ipairs(armorPlayersE) do
			if enemy:getArmor():isKindOf("Vine") or self:isWeak(enemy) then
				return "armor"
			end
		end
	end

	self.player:setFlags("-mumu_armor")
	if #weaponPlayersE > 0 then
		return "weapon"
	end
	self.player:setFlags("mumu_armor")
	if #armorPlayersE > 0 then
		for _,enemy in ipairs(armorPlayersE) do
			if not enemy:getArmor():isKindOf("SilverLion") and enemy:getLostHp() > 0 then
				return "armor"
			end
		end
	end
	self.player:setFlags("-mumu_armor")
	return "cancel"
end

sgs.ai_skill_playerchosen.mumu = function(self, targets)
	if self.player:hasFlag("mumu_armor") then
		for _,target in sgs.qlist(targets) do
			if self:isFriend(target) and target:getArmor():isKindOf("SilverLion") and target:getLostHp() > 0 then return target end
			if self:isEnemy(target) and target:getArmor():isKindOf("SilverLion") and target:getLostHp() == 0 then return target end
		end
		for _,target in sgs.qlist(targets) do
			if self:isEnemy(target) and (self:isWeak(target) or target:getArmor():isKindOf("Vine")) then return target end
		end
		for _,target in sgs.qlist(targets) do
			if self:isEnemy(target) then return target end
		end
	else
		for _,target in sgs.qlist(targets) do
			if self:isEnemy(target) and target:hasSkills("liegong|qiangxi|jijiu|guidao|anjian") then return target end
		end
		for _,target in sgs.qlist(targets) do
			if self:isEnemy(target) then return target end
		end
	end
	return targets:at(0)
end

-- 协穆
local xiemu_skill = {}
xiemu_skill.name = "xiemu"
table.insert(sgs.ai_skills, xiemu_skill)
xiemu_skill.getTurnUseCard = function(self)
	if self.player:hasUsed("XiemuCard") then return end
	if self:getCardsNum("Slash") == 0 then return end

	local kingdomDistribute = {}
	kingdomDistribute["wei"] = 0;
	kingdomDistribute["shu"] = 0;
	kingdomDistribute["wu"] = 0;
	kingdomDistribute["qun"] = 0;
	for _,p in sgs.qlist(self.room:getAlivePlayers()) do
		if kingdomDistribute[p:getKingdom()] and self:isEnemy(p) and p:inMyAttackRange(self.player)
			then kingdomDistribute[p:getKingdom()] = kingdomDistribute[p:getKingdom()] + 1
			else kingdomDistribute[p:getKingdom()] = kingdomDistribute[p:getKingdom()] + 0.2 end
		if p:hasSkill("luanji") and p:getHandcardNum() > 2 then kingdomDistribute["qun"] = kingdomDistribute["qun"] + 3 end
		if p:hasSkill("qixi") and self:isEnemy(p) and p:getHandcardNum() > 2 then kingdomDistribute["wu"] = kingdomDistribute["wu"] + 2 end
		if p:hasSkill("zaoxian") and self:isEnemy(p) and p:getPile("field"):length() > 1 then kingdomDistribute["wei"] = kingdomDistribute["wei"] + 2 end
	end
	maxK = "wei"
	if kingdomDistribute["shu"] > kingdomDistribute[maxK] then maxK = "shu" end
	if kingdomDistribute["wu"] > kingdomDistribute[maxK] then maxK = "wu" end
	if kingdomDistribute["qun"] > kingdomDistribute[maxK] then maxK = "qun" end
	if kingdomDistribute[maxK] + self:getCardsNum("Slash") < 4 then return end
	local newData = sgs.QVariant(maxK)
	self.room:setTag("xiemu_choice", newData)
	local subcard
	for _,c in sgs.qlist(self.player:getHandcards()) do
		if c:isKindOf("Slash") then subcard = c end
	end
	if not subcard then return end
	return sgs.Card_Parse("@XiemuCard=" .. subcard:getEffectiveId())
end

sgs.ai_skill_use_func.XiemuCard = function(card, use, self)
	if self.player:hasUsed("XiemuCard") then return end
	use.card = card
end

sgs.ai_skill_choice.xiemu = function(self, choices)
	local choice = self.room:getTag("xiemu_choice"):toString()
	self.room:setTag("xiemu_choice", sgs.QVariant())
	return choice
end

sgs.ai_use_value.XiemuCard = 5
sgs.ai_use_priority.XiemuCard = 10

sgs.ai_cardneed.xiemu = sgs.ai_cardneed.lieren

-- 纳蛮
sgs.ai_skill_invoke.naman = function(self, data)
	if self:needKongcheng(self.player, true) and self.player:getHandcardNum() == 0 then return false end
	return true
end

-- 设伏
sgs.ai_skill_use["@@shefu"] = function(self, data)
	local record
	for _, friend in ipairs(self.friends) do
		if self:isWeak(friend) then
			for _, enemy in ipairs(self.enemies) do
				if enemy:inMyAttackRange(friend) then
					if self.player:getMark("Shefu_slash") == 0 then
						record = "slash"
					end
				end
			end
		end
	end
	if not record then
		for _, enemy in ipairs(self.enemies) do
			if self:isWeak(enemy) then
				for _, friend in ipairs(self.friends) do
					if friend:inMyAttackRange(enemy) then
						if self.player:getMark("Shefu_peach") == 0 then
							record = "peach"
						elseif self.player:getMark("Shefu_jink") == 0 then
							record = "jink"
						end
					end
				end
			end
		end
	end
	if not record then
		for _, enemy in ipairs(self.enemies) do
			if enemy:getHp() == 1 then
				if self.player:getMark("Shefu_peach") == 0 then
					record = "peach"
				end
			end
		end
	end
	if not record then
		for _, enemy in ipairs(self.enemies) do
			if getKnownCard(enemy, self.player, "ArcheryAttack", false) > 0 or (enemy:hasSkill("luanji") and enemy:getHandcardNum() > 3)
			and self.player:getMark("Shefu_archery_attack") == 0 then
				record = "archery_attack"
			elseif getKnownCard(enemy, self.player, "SavageAssault", false) > 0
			and self.player:getMark("Shefu_savage_assault") == 0 then
				record = "savage_assault"
			elseif getKnownCard(enemy, self.player, "Indulgence", false) > 0 or (enemy:hasSkills("guose|nosguose") and enemy:getHandcardNum() > 2)
			and self.player:getMark("Shefu_indulgence") == 0 then
				record = "indulgence"
			end
		end
	end
	for _, player in sgs.qlist(self.room:getAlivePlayers()) do
		if player:containsTrick("lightning") and self:hasWizard(self.enemies) then
			if self.player:getMark("Shefu_lightning") == 0 then
				record = "lightning"
			end
		end
	end
	if not record then
		if self.player:getMark("Shefu_slash") == 0 then
			record = "slash"
		elseif self.player:getMark("Shefu_peach") == 0 then
			record = "peach"
		end
	end

	local cards = sgs.QList2Table(self.player:getHandcards())
	local use_card
	self:sortByKeepValue(cards)
	for _,card in ipairs(cards) do
		if not card:isKindOf("Peach") and not (self:isWeak() and card:isKindOf("Jink"))then
			use_card = card
		end
	end
	if record and use_card then
		return "@ShefuCard="..use_card:getEffectiveId()..":"..record
	end
end

sgs.ai_skill_invoke.shefu_cancel = function(self)
	local data = self.room:getTag("ShefuData")
	local use = data:toCardUse()
	local from = use.from
	local to = use.to:first()
	if from and self:isEnemy(from) then
		if (use.card:isKindOf("Jink") and self:isWeak(from))
		or (use.card:isKindOf("Peach") and self:isWeak(from))
		or use.card:isKindOf("Indulgence")
		or use.card:isKindOf("ArcheryAttack") or use.card:isKindOf("SavageAssault") then
			return true
		end
	end
	if to and self:isFriend(to) then
		if (use.card:isKindOf("Slash") and self:isWeak(to))
		or use.card:isKindOf("Lightning") then
			return true
		end
	end
return false
end

-- 贲育
sgs.ai_skill_invoke.benyu = function(self, data)
	return true
end

sgs.ai_skill_cardask["@@benyu"] = function(self, data)
	local damage = self.room:getTag("CurrentDamageStruct"):toDamage()
	if not damage.from or self.player:isKongcheng() or not self:isEnemy(damage.from) then return "." end

	local needcard_num = damage.from:getHandcardNum() + 1
	local cards = self.player:getCards("he")
	local to_discard = {}
	cards = sgs.QList2Table(cards)
	self:sortByKeepValue(cards)
	for _, card in ipairs(cards) do
		if not card:isKindOf("Peach") or damage.from:getHp() == 1 then
			table.insert(to_discard, card:getEffectiveId())
			if #to_discard == needcard_num then break end
		end
	end

	if #to_discard == needcard_num then
		return "$" .. table.concat(to_discard, "+")
	end

return "."
end

-- 淑慎
sgs.ai_skill_choice.shushen = function(self, choices)
	return self.shushenchoice
end

sgs.ai_skill_playerchosen.shushen = function(self, targets)
	if #self.friends_noself == 0 then return nil end
	local target
	self:sort(self.friends_noself, "defense")
	for _, friend in ipairs(self.friends_noself) do
		if self:isWeak(friend) then
			target = friend break
		end
	end
	if target then
		self.shushenchoice = "recover"
	else
		target = self:findPlayerToDraw(false, 2)
		self.shushenchoice = "draw"
	end
return target
end

sgs.ai_card_intention.ShushenCard = -80

-- 神智
sgs.ai_skill_invoke.shenzhi = function(self, data)
	if self:getCardsNum("Peach") > 0 then return false end
	if self.player:getHandcardNum() >= 3 then return false end
	if self.player:getHandcardNum() >= self.player:getHp() and self.player:isWounded() then return true end
	if self.player:hasSkill("beifa") and self.player:getHandcardNum() == 1 and self:needKongcheng() then return true end
	if self.player:hasSkill("sijian") and self.player:getHandcardNum() == 1 then return true end
	return false
end

function sgs.ai_cardneed.shenzhi(to, card)
	return to:getHandcardNum() < to:getHp()
end

-- 符箓
sgs.ai_view_as.fulu = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card_place ~= sgs.Player_PlaceSpecial and card:getClassName() == "Slash" and not card:hasFlag("using") then
		return ("thunder_slash:fulu[%s:%s]=%d"):format(suit, number, card_id)
	end
end

sgs.ai_skill_invoke.fulu = function(self, data)
	local use = data:toCardUse()
	for _, player in sgs.qlist(use.to) do
		if self:isEnemy(player) and self:damageIsEffective(player, sgs.DamageStruct_Thunder) and sgs.isGoodTarget(player, self.enemies, self) then
			return true
		end
	end
	return false
end

local fulu_skill = {}
fulu_skill.name = "fulu"
table.insert(sgs.ai_skills, fulu_skill)
fulu_skill.getTurnUseCard = function(self, inclusive)
	local cards = self.player:getCards("h")
	cards = sgs.QList2Table(cards)

	local slash
	self:sortByUseValue(cards, true)
	for _, card in ipairs(cards) do
		if card:getClassName() == "Slash" then
			slash = card
			break
		end
	end

	if not slash then return nil end
	local dummy_use = { to = sgs.SPlayerList(), isDummy = true }
	self:useCardThunderSlash(slash, dummy_use)
	if dummy_use.card and dummy_use.to:length() > 0 then
		local use = sgs.CardUseStruct()
		use.from = self.player
		use.to = dummy_use.to
		use.card = slash
		local data = sgs.QVariant()
		data:setValue(use)
		if not sgs.ai_skill_invoke.fulu(self, data) then return nil end
	else return nil end

	if slash then
		local suit = slash:getSuitString()
		local number = slash:getNumberString()
		local card_id = slash:getEffectiveId()
		local card_str = ("thunder_slash:fulu[%s:%s]=%d"):format(suit, number, card_id)
		local mySlash = sgs.Card_Parse(card_str)

		assert(mySlash)
		return mySlash
	end
end

sgs.ai_cardneed.fulu = sgs.ai_cardneed.lieren

-- 助祭
sgs.ai_skill_invoke.zhuji = function(self, data)
	local damage = data:toDamage()
	if self:isFriend(damage.from) and not self:isFriend(damage.to) then return true end
	return false
end

-- 镇卫
sgs.ai_skill_cardask["@sp_zhenwei"] = function(self, data)
	local use = data:toCardUse()
	if use.to:length() ~= 1 or not use.from or not use.card then return "." end
	if not self:isFriend(use.to:at(0)) or self:isFriend(use.from) then return "." end
	if use.to:at(0):hasSkills("liuli|tianxiang") and use.card:isKindOf("Slash") and use.to:at(0):getHandcardNum() > 1 then return "." end
	if use.card:isKindOf("Slash") and not self:slashIsEffective(use.card, use.to:at(0), use.from) then return "." end
	if use.to:at(0):hasSkills(sgs.masochism_skill) and not use.to:at(0):isWeak() then return "." end
	if self.player:getHandcardNum() + self.player:getEquips():length() < 2 and not self:isWeak(use.to:at(0)) then return "." end
	local to_discard = self:askForDiscard("sp_zhenwei", 1, 1, false, true)
	if #to_discard > 0 then
		if not (use.card:isKindOf("Slash") and  self:isWeak(use.to:at(0))) and sgs.Sanguosha:getCard(to_discard[1]):isKindOf("Peach") then return "." end
		return "$" .. to_discard[1]
	else
		return "."
	end
end

sgs.ai_skill_choice.spzhenwei = function(self, choices, data)
	local use = data:toCardUse()
	if self:isWeak() or self.player:getHandcardNum() < 2 then return "null" end
	if use.card:isKindOf("TrickCard") and use.from:hasSkill("jizhi") then return "draw" end
	if use.card:isKindOf("Slash") and (use.from:hasSkills("paoxiao|tianyi|xianzhen|jiangchi|fuhun|qiangwu")
		or (use.from:getWeapon() and use.from:getWeapon():isKindOf("Crossbow"))) and self:getCardsNum("Jink") == 0 then return "null" end
	if use.card:isKindOf("SupplyShortage") then return "null" end
	if use.card:isKindOf("Slash") and self:getCardsNum("Jink") == 0 and self.player:getLostHp() > 0 then return "null" end
	if use.card:isKindOf("Indulgence") and self.player:getHandcardNum() + 1 > self.player:getHp() then return "null" end
	if use.card:isKindOf("Slash") and use.from:hasSkills("tieqi|wushuang|yijue|liegong|mengjin|qianxi") and not (use.from:getWeapon() and use.from:getWeapon():isKindOf("Crossbow")) then return "null" end
	return "draw"
end

-- 去疾
local quji_skill = {}
quji_skill.name = "quji"
table.insert(sgs.ai_skills, quji_skill)
quji_skill.getTurnUseCard = function(self)
	if self.player:getHandcardNum() < self.player:getLostHp() then return nil end
	if self.player:usedTimes("QujiCard") > 0 then return nil end
	if self.player:getLostHp() == 0 then return end

	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)

	local arr1, arr2 = self:getWoundedFriend(false, true)
	if #arr1 + #arr2 < self.player:getLostHp() then return end

	local compare_func = function(a, b)
		local v1 = self:getKeepValue(a) + ( a:isBlack() and 50 or 0 ) + ( a:isKindOf("Peach") and 50 or 0 )
		local v2 = self:getKeepValue(b) + ( b:isBlack() and 50 or 0 ) + ( b:isKindOf("Peach") and 50 or 0 )
		return v1 < v2
	end
	table.sort(cards, compare_func)

	if cards[1]:isBlack() and self:getLostHp() > 0 then return end
	if self.player:getLostHp() == 2 and (cards[1]:isBlack() or cards[2]:isBlack()) then return end

	local card_str = "@QujiCard="..cards[1]:getId()
	local left = self.player:getLostHp() - 1
	while left > 0 do
		card_str = card_str.."+"..cards[self.player:getLostHp() + 1 - left]:getId()
		left = left - 1
	end

	return sgs.Card_Parse(card_str)
end

sgs.ai_skill_use_func.QujiCard = function(card, use, self)
	local arr1, arr2 = self:getWoundedFriend(false, true)
	local target = nil
	local num = self.player:getLostHp()
	for num = 1, self.player:getLostHp() do
		if #arr1 > num - 1 and (self:isWeak(arr1[num]) or self:getOverflow() >= 1) and arr1[num]:getHp() < getBestHp(arr1[num]) then target = arr1[num] end
		if target then
			if use.to then use.to:append(target) end
		else
			break
		end
	end

	if num < self.player:getLostHp() then
		if #arr2 > 0 then
			for _, friend in ipairs(arr2) do
				if not friend:hasSkills("hunzi|longhun") then
					if use.to then
						use.to:append(friend)
						num = num + 1
						if num == self.player:getLostHp() then break end
					end
				end
			end
		end
	end
	use.card = card
	return
end

sgs.ai_use_priority.QujiCard = 4.2
sgs.ai_card_intention.QujiCard = -100
sgs.dynamic_value.benefit.QujiCard = true

sgs.quji_suit_value = {
	heart = 6,
	diamond = 6
}

sgs.ai_cardneed.quji = function(to, card)
	return card:isRed()
end

-- 郡兵
sgs.ai_skill_invoke.junbing = function(self, data)
	local simalang = self.room:findPlayerBySkillName("junbing")
	if self:isFriend(simalang) then return true end
	return false
end

-- 残蚀
sgs.ai_skill_invoke.canshi = function(self, data)
	local n = 0
	for _, p in sgs.qlist(self.room:getAlivePlayers()) do
		if p:isWounded() or (self.player:hasSkill("guiming") and self.player:isLord() and p:getKingdom() == "wu" and self.player:objectName() ~= p:objectName()) then n = n + 1 end
	end
	if n <= 2 then return false end
	if n == 3 and (not self:isWeak() or self:willSkipPlayPhase()) then return true end
	if n > 3 then return true end
	return false
end

-- 焚天
sgs.ai_skill_playerchosen.fentian = function(self, targets)
	self:sort(self.enemies,"defense")
	for _, enemy in ipairs(self.enemies) do
		if (not self:doNotDiscard(enemy) or self:getDangerousCard(enemy) or self:getValuableCard(enemy)) and not enemy:isNude() and self.player:inMyAttackRange(enemy) then
			return enemy
		end
	end
	for _, friend in ipairs(self.friends) do
		if(self:hasSkills(sgs.lose_equip_skill, friend) and not friend:getEquips():isEmpty())
		or (self:needToThrowArmor(friend) and friend:getArmor()) or self:doNotDiscard(friend) and self.player:inMyAttackRange(friend) then
			return friend
		end
	end
	for _, enemy in ipairs(self.enemies) do
		if not enemy:isNude() and self.player:inMyAttackRange(enemy) then
			return enemy
		end
	end
	for _, friend in ipairs(self.friends) do
		if not friend:isNude() and self.player:inMyAttackRange(friend) then
			return friend
		end
	end
end

sgs.ai_playerchosen_intention.fentian = 20

-- 心惔
local getXintanCard = function(pile)
	if #pile > 1 then return pile[1], pile[2] end
	return nil
end

local xintan_skill = {}
xintan_skill.name = "xintan"
table.insert(sgs.ai_skills, xintan_skill)
xintan_skill.getTurnUseCard=function(self)
	if self.player:hasUsed("XintanCard") then return end
	if self.player:getPile("burn"):length() <= 1 then return end
	local ints = sgs.QList2Table(self.player:getPile("burn"))
	local a, b = getXintanCard(ints)
	if a and b then
		return sgs.Card_Parse("@XintanCard=" .. tostring(a) .. "+" .. tostring(b))
	end
end

sgs.ai_skill_use_func.XintanCard = function(card, use, self)
	local target
	self:sort(self.enemies, "hp")
	for _, enemy in ipairs(self.enemies) do
		if not self:needToLoseHp(enemy, self.player) and ((self:isWeak(enemy) or enemy:getHp() == 1) or self.player:getPile("burn"):length() > 3)  then
			target = enemy
		end
	end
	if not target then
		for _, friend in ipairs(self.friends) do
			if not self:needToLoseHp(friend, self.player) then
				target = friend
			end
		end
	end
	if target then
		use.card = card
		if use.to then use.to:append(target) end
		return
	end
end

sgs.ai_use_priority.XintanCard = 7
sgs.ai_use_value.XintanCard = 3
sgs.ai_card_intention.XintanCard = 80
