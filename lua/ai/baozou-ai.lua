sgs.ai_skill_playerchosen.LuaShensu = function(self, targets)
	return sgs.ai_skill_playerchosen.zero_card_as_slash(self, targets)
end

sgs.ai_skill_invoke.LuaYizhong = function(self, data)
	local target = data:toPlayer()
	if target:hasSkill("zhaxiang") then return false end
	if not self:isFriend(target) then return true end
	return false
end
