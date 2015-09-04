-- 困奋
sgs.ai_skill_invoke.kunfen = function(self, data)
	if not self:isWeak() and (self.player:getHp() > 2 or (self:getCardsNum("Peach") > 0 and self.player:getHp() > 1)) then
		return true
	end
	return false
end

-- 赤心
local chixin_skill={}
chixin_skill.name="chixin"
table.insert(sgs.ai_skills,chixin_skill)
chixin_skill.getTurnUseCard = function(self, inclusive)
	local cards = self.player:getCards("he")
	cards=sgs.QList2Table(cards)

	local diamond_card

	self:sortByUseValue(cards,true)

	local useAll = false
	self:sort(self.enemies, "defense")
	for _, enemy in ipairs(self.enemies) do
		if enemy:getHp() == 1 and not enemy:hasArmorEffect("EightDiagram") and self.player:distanceTo(enemy) <= self.player:getAttackRange() and self:isWeak(enemy)
			and getCardsNum("Jink", enemy, self.player) + getCardsNum("Peach", enemy, self.player) + getCardsNum("Analeptic", enemy, self.player) == 0 then
			useAll = true
			break
		end
	end

	local disCrossbow = false
	if self:getCardsNum("Slash") < 2 or self.player:hasSkill("paoxiao") then
		disCrossbow = true
	end


	for _,card in ipairs(cards)  do
		if card:getSuit() == sgs.Card_Diamond
		and (not isCard("Peach", card, self.player) and not isCard("ExNihilo", card, self.player) and not useAll)
		and (not isCard("Crossbow", card, self.player) and not disCrossbow)
		and (self:getUseValue(card) < sgs.ai_use_value.Slash or inclusive or sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_Residue, self.player, sgs.Sanguosha:cloneCard("slash")) > 0) then
			diamond_card = card
			break
		end
	end

	if not diamond_card then return nil end
	local suit = diamond_card:getSuitString()
	local number = diamond_card:getNumberString()
	local card_id = diamond_card:getEffectiveId()
	local card_str = ("slash:chixin[%s:%s]=%d"):format(suit, number, card_id)
	local slash = sgs.Card_Parse(card_str)
	assert(slash)

	return slash

end

sgs.ai_view_as.chixin = function(card, player, card_place, class_name)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card_place ~= sgs.Player_PlaceSpecial and card:getSuit() == sgs.Card_Diamond and not card:isKindOf("Peach") and not card:hasFlag("using") then
		if class_name == "Slash" then
			return ("slash:chixin[%s:%s]=%d"):format(suit, number, card_id)
		elseif class_name == "Jink" then
			return ("jink:chixin[%s:%s]=%d"):format(suit, number, card_id)
		end
	end
end

sgs.ai_cardneed.chixin = function(to, card)
	return card:getSuit() == sgs.Card_Diamond
end

-- 随仁
sgs.ai_skill_playerchosen.suiren = function(self, targets)
	if self.player:getMark("@suiren") == 0 then return "." end
	if self:isWeak() and (self:getOverflow() < -2 or not self:willSkipPlayPhase()) then return self.player end
	self:sort(self.friends_noself, "defense")
	for _, friend in ipairs(self.friends) do
		if self:isWeak(friend) and not self:needKongcheng(friend) then
			return friend
		end
	end
	self:sort(self.enemies, "defense")
	for _, enemy in ipairs(self.enemies) do
		if (self:isWeak(enemy) and enemy:getHp() == 1)
			and self.player:getHandcardNum() < 2 and not self:willSkipPlayPhase() and self.player:inMyAttackRange(enemy) then
			return self.player
		end
	end
end

sgs.ai_playerchosen_intention.suiren = -60

-- 机巧

-- 玲珑
sgs.ai_skill_invoke.linglong = sgs.ai_skill_invoke.bazhen

sgs.ai_armor_value.linglong = sgs.ai_armor_value.bazhen

sgs.ai_cardneed.linglong = function(to, card)
	return not card:isKindOf("EquipCard")
end