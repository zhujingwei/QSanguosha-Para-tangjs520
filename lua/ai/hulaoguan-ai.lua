sgs.ai_skill_invoke["weapon_recast"] = function(self, data)
	if self:hasSkills(sgs.lose_equip_skill, self.player) then return false end
	if self.player:isLord() then
		local card_use = data:toCardUse()
		if card_use.card:objectName() ~= "Crossbow" then return true else return false end
	else
		if self.player:getWeapon() then return true else return false end
	end
end

sgs.ai_skill_invoke["draw_1v3"] = function(self, data)
	return not self:needKongcheng(self.player, true)
end

sgs.ai_skill_choice.Hulaopass = "recover"
