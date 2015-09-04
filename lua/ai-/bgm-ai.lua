-- 冲阵
sgs.ai_skill_invoke.chongzhen = function(self, data)
	local target = data:toPlayer()
	if self:isFriend(target) then
		if hasManjuanEffect(self.player) then return false end
		if self:needKongcheng(target) and target:getHandcardNum() == 1 then return true end
		if self:getOverflow(target) > 2 then return true end
		return false
	else
		return not (self:needKongcheng(target) and target:getHandcardNum() == 1)
	end
end

sgs.ai_choicemade_filter.skillInvoke.chongzhen = function(self, player, promptlist)
	local target = findPlayerByObjectName(self.room, promptlist[#promptlist - 1])
	if target then
		local intention = 60
		if promptlist[#promptlist] == "yes" then
			if not self:hasLoseHandcardEffective(target) or (self:needKongcheng(target) and target:getHandcardNum() == 1) then
				intention = 0
			end
			if self:getOverflow(target) > 2 then intention = 0 end
			sgs.updateIntention(player, target, intention)
		else
			if self:needKongcheng(target) and target:getHandcardNum() == 1 then intention = 0 end
			sgs.updateIntention(player, target, -intention)
		end
	end
end

sgs.ai_slash_prohibit.chongzhen = function(self, from, to, card)
	if self:isFriend(to, from) then return false end
	if not sgs.isJinkAvailable(from, to, card) then return false end
	if to:hasSkill("longdan") and to:getHandcardNum() >= 3 and from:getHandcardNum() > 1 then return true end
	return false
end

-- 离魂
local lihun_skill = {}
lihun_skill.name = "lihun"
table.insert(sgs.ai_skills, lihun_skill)
lihun_skill.getTurnUseCard = function(self)
	if self.player:hasUsed("LihunCard") or self.player:isNude() then return end
	local card_id
	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	self:sortByKeepValue(cards)
	local lightning = self:getCard("Lightning")

	if self:needToThrowArmor() then
		card_id = self.player:getArmor():getId()
	elseif self.player:getHandcardNum() > self.player:getHp() then
		if lightning and not self:willUseLightning(lightning) then
			card_id = lightning:getEffectiveId()
		else
			for _, acard in ipairs(cards) do
				if (acard:isKindOf("BasicCard") or acard:isKindOf("EquipCard") or acard:isKindOf("AmazingGrace"))
					and not acard:isKindOf("Peach") then
					card_id = acard:getEffectiveId()
					break
				end
			end
		end
	elseif not self.player:getEquips():isEmpty() then
		local player = self.player
		if player:getWeapon() then card_id = player:getWeapon():getId()
		elseif player:getOffensiveHorse() then card_id = player:getOffensiveHorse():getId()
		elseif player:getDefensiveHorse() then card_id = player:getDefensiveHorse():getId()
		elseif player:getArmor() and player:getHandcardNum() <= 1 then card_id = player:getArmor():getId()
		end
	end
	if not card_id then
		if lightning and not self:willUseLightning(lightning) then
			card_id = lightning:getEffectiveId()
		else
			for _, acard in ipairs(cards) do
				if (acard:isKindOf("BasicCard") or acard:isKindOf("EquipCard") or acard:isKindOf("AmazingGrace"))
					and not acard:isKindOf("Peach") then
					card_id = acard:getEffectiveId()
					break
				end
			end
		end
	end
	if not card_id then
		return nil
	else
		return sgs.Card_Parse("@LihunCard=" .. card_id)
	end
end

sgs.ai_skill_use_func.LihunCard = function(card, use, self)
	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)

	if not self.player:hasUsed("LihunCard") then
		self:sort(self.enemies, "handcard")
		self.enemies = sgs.reverse(self.enemies)
		local target
		local jwfy = self.room:findPlayerBySkillName("shoucheng")
		for _, enemy in ipairs(self.enemies) do
			if enemy:isMale() and not enemy:isKongcheng() and not enemy:hasSkill("kongcheng") then
				if ((enemy:hasSkills("lianying|noslianying") or (jwfy and self:isFriend(jwfy, enemy))) and self:damageMinusHp(self, enemy, 1) > 0)
					or (enemy:getHp() < 3 and self:damageMinusHp(self, enemy, 0) > 0 and enemy:getHandcardNum() > 0)
					or (enemy:getHandcardNum() >= enemy:getHp() and enemy:getHp() > 2 and self:damageMinusHp(self, enemy, 0) >= -1)
					or (enemy:getHandcardNum() - enemy:getHp() > 2) then
					target = enemy
					break
				end
			end
		end
		if not self.player:faceUp() and not target then
			for _, enemy in ipairs(self.enemies) do
				if enemy:isMale() and not enemy:isKongcheng() then
					if enemy:getHandcardNum() >= enemy:getHp() then
						target = enemy
						break
					end
				end
			end
		end

		if not target and (self:hasCrossbowEffect() or self:getCardsNum("Crossbow") > 0) then
			local slash = self:getCard("Slash") or sgs.cloneCard("slash")
			for _, enemy in ipairs(self.enemies) do
				if enemy:isMale() and self:slashIsEffective(slash, enemy) and self.player:distanceTo(enemy) == 1
					and not enemy:hasSkills("fenyong|zhichi|fankui|nosfankui|ganglie|vsganglie|nosganglie|enyuan|nosenyuan|langgu|guixin|kongcheng")
					and self:getCardsNum("Slash") + getKnownCard(enemy, self.player, "Slash") >= 3 then
					target = enemy
					break
				end
			end
		end

		if target then
			use.card = card
			if use.to then use.to:append(target) end
		end
	end
end

function SmartAI:isLihunTarget(player, drawCardNum)
	player = player or self.player
	drawCardNum = drawCardNum or 1
	if type(player) == "table" then
		if #player == 0 then return false end
		for _, ap in ipairs(player) do
			if self:isLihunTarget(ap, drawCardNum) then return true end
		end
		return false
	end

	local handCardNum = player:getHandcardNum() + drawCardNum
	if not player:isMale() then return false end

	local sb_diaochan = self.room:findPlayerBySkillName("lihun")
	local lihun = sb_diaochan and not sb_diaochan:hasUsed("LihunCard") and not self:isFriend(sb_diaochan)

	if not lihun then return false end

	if sb_diaochan:getPhase() == sgs.Player_Play then
		if (handCardNum - player:getHp() >= 2)
			or (handCardNum > 0 and handCardNum - player:getHp() >= -1 and not sb_diaochan:faceUp()) then
			return true
		end
	else
		if sb_diaochan:faceUp() and not self:willSkipPlayPhase(sb_diaochan)
			and self:playerGetRound(player) > self:playerGetRound(sb_diaochan) and handCardNum >= player:getHp() + 2 then
			return true
		end
	end

	return false
end

sgs.ai_skill_discard.lihun = function(self, discard_num, min_num, optional, include_equip)
	local to_discard = {}

	local cards = sgs.QList2Table(self.player:getCards("he"))
	self:sortByKeepValue(cards)
	local card_ids = {}
	for _, card in ipairs(cards) do
		table.insert(card_ids, card:getEffectiveId())
	end

	local temp = table.copyFrom(card_ids)
	for i = 1, #temp, 1 do
		local card = sgs.Sanguosha:getCard(temp[i])
		if self.player:getArmor() and temp[i] == self.player:getArmor():getEffectiveId() and self:needToThrowArmor() then
			table.insert(to_discard, temp[i])
			table.removeOne(card_ids, temp[i])
			if #to_discard == discard_num then
				return to_discard
			end
		end
	end

	temp = table.copyFrom(card_ids)

	for i = 1, #card_ids, 1 do
		local card = sgs.Sanguosha:getCard(card_ids[i])
		table.insert(to_discard, card_ids[i])
		if #to_discard == discard_num then
			return to_discard
		end
	end

	if #to_discard < discard_num then return {} end
end

sgs.ai_use_value.LihunCard = 8.5
sgs.ai_use_priority.LihunCard = 6
sgs.ai_card_intention.LihunCard = 80

-- 溃围
function sgs.ai_skill_invoke.kuiwei(self, data)
	local sbdiaochan = self.room:findPlayerBySkillName("lihun")
	if sbdiaochan and sbdiaochan:faceUp() and not self:willSkipPlayPhase(sbdiaochan)
		and (self:isEnemy(sbdiaochan) or (sgs.turncount <= 1 and sgs.evaluatePlayerRole(sbdiaochan) == "neutral")) then return false end
	local weapon = 0
	if not self.player:faceUp() then return true end
	for _, friend in ipairs(self.friends) do
		if friend:hasSkills("fangzhu|jilve") then return true end
		if friend:hasSkill("junxing") and friend:faceUp() and not self:willSkipPlayPhase(friend)
			and not (friend:isKongcheng() and self:willSkipDrawPhase(friend)) then
			return true
		end
	end
	for _, aplayer in sgs.qlist(self.room:getAlivePlayers()) do
		if aplayer:getWeapon() then weapon = weapon + 1 end
	end
	if weapon > 1 then return true end
	return self:isWeak()
end

-- 严整
sgs.ai_view_as.yanzheng = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card_place == sgs.Player_PlaceEquip and player:getHandcardNum() > player:getHp() then
		return ("nullification:yanzheng[%s:%s]=%d"):format(suit, number, card_id)
	end
end
