-- 恢拓
sgs.ai_skill_playerchosen.huituo = function(self, targets)
    self:sort(self.friends, "defense")
    return self.friends[1]
end

sgs.ai_playerchosen_intention.huituo = -80

-- 明鉴
sgs.ai_skill_playerchosen.mingjian = function(self, targets)
    if (sgs.ai_skill_invoke.fangquan(self) or self:needKongcheng(self.player)) then
        local cards = sgs.QList2Table(self.player:getHandcards())
        self:sortByKeepValue(cards)
        if sgs.current_mode_players.rebel == 0 then
            local lord = self.room:getLord()
            if lord and self:isFriend(lord) and lord:objectName() ~= self.player:objectName() then
                return lord
            end
        end

        local AssistTarget = self:AssistTarget()
        if AssistTarget and not self:willSkipPlayPhase(AssistTarget) then
            return AssistTarget
        end

        self:sort(self.friends_noself, "chaofeng")
        return self.friends_noself[1]
    end
    return nil
end

sgs.ai_playerchosen_intention.mingjian = -80

-- 兴衰
sgs.ai_skill_invoke.xingshuai = function(self, data)
	local dying = data:toDying()
	local peaches = 1 - dying.who:getHp()
	self.xingshuai_source = dying.who
	return self:getCardsNum("Peach") + self:getCardsNum("Analeptic") < peaches
end

sgs.ai_skill_invoke._xingshuai = function(self)
	if self:isEnemy(self.xingshuai_source) then return false end
    return self:hasSkills(sgs.masochism_skill) or self.player:getHp() > 1
end


-- 讨袭
--player->askForSkillInvoke(objectName(), QVariant::fromValue(to))
sgs.ai_skill_invoke["taoxi"] = function(self, data)
    local to = data:toPlayer()
    if to and self:isEnemy(to) then

        if self.player:hasSkill("lihun") and to:isMale() and not self.player:hasUsed("LihunCard") then
            local callback = lihun_skill.getTurnUseCard
            if type(callback) == "function" then
                local skillcard = callback(self)
                if skillcard then
                    local dummy_use = {
                        isDummy = true,
                        to = sgs.SPlayerList(),
                    }
                    self:useSkillCard(skillcard, dummy_use)
                    if dummy_use.card then
                        for _,p in sgs.qlist(dummy_use.to) do
                            if p:objectName() == to:objectName() then
                                return true
                            end
                        end
                    end
                end
            end
        end

        if self.player:hasSkill("dimeng") and not self.player:hasUsed("DimengCard") then
            local callback = dimeng_skill.getTurnUseCard
            if type(callback) == "function" then
                local skillcard = callback(self)
                if skillcard then
                    local dummy_use = {
                        isDummy = true,
                        to = sgs.SPlayerList(),
                    }
                    self:useSkillCard(skillcard, dummy_use)
                    if dummy_use.card then
                        for _,p in sgs.qlist(dummy_use.to) do
                            if p:objectName() == to:objectName() then
                                return true
                            end
                        end
                    end
                end
            end
        end

        local dismantlement_count = 0
        if to:hasSkill("noswuyan") or to:getMark("@late") > 0 then
            if self.player:hasSkill("yinling") then
                local black = self:getSuitNum("spade|club", true)
                local num = 4 - self.player:getPile("brocade"):length()
                dismantlement_count = dismantlement_count + math.max(0, math.min(black, num))
            end
        else
            dismantlement_count = dismantlement_count + self:getCardsNum("Dismantlement")
            if self.player:distanceTo(to) == 1 or self:hasSkills("qicai|nosqicai") then
                dismantlement_count = dismantlement_count + self:getCardsNum("Snatch")
            end
        end

        local handcards = to:getHandcards()
        if dismantlement_count >= handcards:length() then
            return true
        end

        local can_use, cant_use = {}, {}
        for _,c in sgs.qlist(handcards) do
            if self.player:isCardLimited(c, sgs.Card_MethodUse, false) then
                table.insert(cant_use, c)
            else
                table.insert(can_use, c)
            end
        end

        if #can_use == 0 and dismantlement_count == 0 then
            return false
        end

        if self:needToLoseHp() then
            --Infact, needToLoseHp now doesn't mean self.player still needToLoseHp when this turn end.
            --So this part may make us upset sometimes... Waiting for more details.
            return true
        end

        local knowns, unknowns = {}, {}
        local flag = string.format("visible_%s_%s", self.player:objectName(), to:objectName())
        for _,c in sgs.qlist(handcards) do
            if c:hasFlag("visible") or c:hasFlag(flag) then
                table.insert(knowns, c)
            else
                table.insert(unknowns, c)
            end
        end

        if #knowns > 0 then --Now I begin to lose control... Need more help.
            local can_use_record = {}
            for _,c in ipairs(can_use) do
                can_use_record[c:getId()] = true
            end

            local can_use_count = 0
            local to_can_use_count = 0
            local function can_use_check(user, to_use)
                if to_use:isKindOf("EquipCard") then
                    return not user:isProhibited(user, to_use)
                elseif to_use:isKindOf("BasicCard") then
                    if to_use:isKindOf("Jink") then
                        return false
                    elseif to_use:isKindOf("Peach") then
                        if user:hasFlag("Global_PreventPeach") then
                            return false
                        elseif user:getLostHp() == 0 then
                            return false
                        elseif user:isProhibited(user, to_use) then
                            return false
                        end
                        return true
                    elseif to_use:isKindOf("Slash") then
                        if to_use:isAvailable(user) then
                            local others = self.room:getOtherPlayers(user)
                            for _,p in sgs.qlist(others) do
                                if user:canSlash(p, to_use) then
                                    return true
                                end
                            end
                        end
                        return false
                    elseif to_use:isKindOf("Analeptic") then
                        if to_use:isAvailable(user) then
                            return not user:isProhibited(user, to_use)
                        end
                    end
                elseif to_use:isKindOf("TrickCard") then
                    if to_use:isKindOf("Nullification") then
                        return false
                    elseif to_use:isKindOf("DelayedTrick") then
                        if user:containsTrick(to_use:objectName()) then
                            return false
                        elseif user:isProhibited(user, to_use) then
                            return false
                        end
                        return true
                    elseif to_use:isKindOf("Collateral") then
                        local others = self.room:getOtherPlayers(user)
                        local selected = sgs.PlayerList()
                        for _,p in sgs.qlist(others) do
                            if to_use:targetFilter(selected, p, user) then
                                local victims = self.room:getOtherPlayers(p)
                                for _,p2 in sgs.qlist(victims) do
                                    if p:canSlash(p2) then
                                        return true
                                    end
                                end
                            end
                        end
                    elseif to_use:isKindOf("ExNihilo") then
                        return not user:isProhibited(user, to_use)
                    else
                        local others = self.room:getOtherPlayers(user)
                        for _,p in sgs.qlist(others) do
                            if not user:isProhibited(p, to_use) then
                                return true
                            end
                        end
                        if to_use:isKindOf("GlobalEffect") and not user:isProhibited(user, to_use) then
                            return true
                        end
                    end
                end
                return false
            end
            for _,c in ipairs(knowns) do
                if can_use_record[c:getId()] and can_use_check(self.player, c) then
                    can_use_count = can_use_count + 1
                end
            end

            local to_friends = self:getFriends(to)
            local to_has_weak_friend = false
            local to_is_weak = self:isWeak(to)
            for _,friend in ipairs(to_friends) do
                if self:isEnemy(friend) and self:isWeak(friend) then
                    to_has_weak_friend = true
                    break
                end
            end

            local my_trick, my_slash, my_aa, my_duel, my_sa = nil, nil, nil, nil, nil
            local use = self.player:getTag("taoxi_carduse"):toCardUse()
            local ucard = use.card
            if ucard:isKindOf("TrickCard") then
                my_trick = 1
                if ucard:isKindOf("Duel") then
                    my_duel = 1
                elseif ucard:isKindOf("ArcheryAttack") then
                    my_aa = 1
                elseif ucard:isKindOf("SavageAssault") then
                    my_sa = 1
                end
            elseif ucard:isKindOf("Slash") then
                my_slash = 1
            end
            
            for _,c in ipairs(knowns) do
                if isCard("Nullification", c, to) then
                    my_trick = my_trick or ( self:getCardsNum("TrickCard") - self:getCardsNum("DelayedTrick") )
                    if my_trick > 0 then
                        to_can_use_count = to_can_use_count + 1
                        continue
                    end
                end
                if isCard("Jink", c, to) then
                    my_slash = my_slash or self:getCardsNum("Slash")
                    if my_slash > 0 then
                        to_can_use_count = to_can_use_count + 1
                        continue
                    end
                    my_aa = my_aa or self:getCardsNum("ArcheryAttack")
                    if my_aa > 0 then
                        to_can_use_count = to_can_use_count + 1
                        continue
                    end
                end
                if isCard("Peach", c, to) then
                    if to_has_weak_friend then
                        to_can_use_count = to_can_use_count + 1
                        continue
                    end
                end
                if isCard("Analeptic", c, to) then
                    if to:getHp() <= 1 and to_is_weak then
                        to_can_use_count = to_can_use_count + 1
                        continue
                    end
                end
                if isCard("Slash", c, to) then
                    my_duel = my_duel or self:getCardsNum("Duel")
                    if my_duel > 0 then
                        to_can_use_count = to_can_use_count + 1
                        continue
                    end
                    my_sa = my_sa or self:getCardsNum("SavageAssault")
                    if my_sa > 0 then
                        to_can_use_count = to_can_use_count + 1
                        continue
                    end
                end
            end

            if can_use_count >= to_can_use_count + #unknowns then
                return true
            elseif can_use_count > 0 and ( can_use_count + 0.01 ) / ( to_can_use_count + 0.01 ) >= 0.5 then
                return true
            end
        end

        if self:getCardsNum("Peach") > 0 then
            return true
        end
    end
    return false
end

-- 怀异
--HuaiyiCard:Play
huaiyi_skill = {
    name = "huaiyi",
    getTurnUseCard = function(self, inclusive)
        if self.player:hasUsed("HuaiyiCard") then
            return nil
        elseif self.player:isKongcheng() then
            return nil
        end
        local handcards = self.player:getHandcards()
        local red, black = false, false
        for _,c in sgs.qlist(handcards) do
            if c:isRed() and not red then
                red = true
                if black then
                    break
                end
            elseif c:isBlack() and not black then
                black = true
                if red then
                    break
                end
            end
        end
        if red and black then
            return sgs.Card_Parse("@HuaiyiCard=.")
        end
    end,
}
table.insert(sgs.ai_skills, huaiyi_skill)
sgs.ai_skill_use_func["HuaiyiCard"] = function(card, use, self)
    local handcards = self.player:getHandcards()
    local reds, blacks = {}, {}
    for _,c in sgs.qlist(handcards) do
        local dummy_use = {
            isDummy = true,
        }
        if c:isKindOf("BasicCard") then
            self:useBasicCard(c, dummy_use)
        elseif c:isKindOf("EquipCard") then
            self:useEquipCard(c, dummy_use)
        elseif c:isKindOf("TrickCard") then
            self:useTrickCard(c, dummy_use)
        end
        if dummy_use.card then
            return --It seems that self.player should use this card first.
        end
        if c:isRed() then
            table.insert(reds, c)
        else
            table.insert(blacks, c)
        end
    end
    
    local targets = self:findPlayerToDiscard("he", false, false, nil, true)
    local n_reds, n_blacks, n_targets = #reds, #blacks, #targets
    if n_targets == 0 then
        return 
    elseif n_reds - n_targets >= 2 and n_blacks - n_targets >= 2 and handcards:length() - n_targets >= 5 then
        return 
    end
    --[[------------------
        Haven't finished.
    ]]--------------------
    use.card = card
end
--room->askForChoice(source, "huaiyi", "black+red")
sgs.ai_skill_choice["huaiyi"] = function(self, choices, data)
    local choice = sgs.huaiyi_choice
    if choice then
        sgs.huaiyi_choice = nil
        return choice
    end
    local handcards = self.player:getHandcards()
    local reds, blacks = {}, {}
    for _,c in sgs.qlist(handcards) do
        if c:isRed() then
            table.insert(reds, c)
        else
            table.insert(blacks, c)
        end
    end
    if #reds < #blacks then
        return "red"
    else
        return "black"
    end
end
--room->askForUseCard(source, "@@huaiyi", "@huaiyi:::" + QString::number(n), -1, Card::MethodNone);
sgs.ai_skill_use["@@huaiyi"] = function(self, prompt, method)
    local n = self.player:getMark("huaiyi_num")
    if n >= 2 then
        if self:needToLoseHp() then
        elseif self:isWeak() then
            n = 1
        end
    end
    if n == 0 then
        return "."
    end
    local targets = self:findPlayerToDiscard("he", false, false, nil, true)
    local names = {}
    for index, target in ipairs(targets) do
        if index <= n then
            table.insert(names, target:objectName())
        else
            break
        end
    end
    return "@HuaiyiSnatchCard=.->"..table.concat(names, "+")
end

-- 急攻
sgs.ai_skill_invoke.jigong = function(self)
    if self.player:isKongcheng() then return true end
    for _, c in sgs.qlist(self.player:getHandcards()) do
        local x = nil
        if isCard("ArcheryAttack", c, self.player) then
            x = sgs.Sanguosha:cloneCard("ArcheryAttack")
        elseif isCard("SavageAssault", c, self.player) then
            x = sgs.Sanguosha:cloneCard("SavageAssault")
        else continue end

        local du = { isDummy = true }
        self:useTrickCard(x, du)
        if (du.card) then return true end
    end

    return false
end

-- 饰非
sgs.ai_skill_invoke.shifei = function(self)
    local l = {}
    for _, p in sgs.qlist(self.room:getAlivePlayers()) do
        l[p:objectName()] = p:getHandcardNum()
        if (p:objectName() == self.room:getCurrent():objectName()) then
            l[p:objectName()] = p:getHandcardNum() + 1
        end
    end

    local most = {}
    for k, t in pairs(l) do
        if #most == 0 then
            table.insert(most, k)
            continue
        end

        if (t > l[most[1]]) then
            most = {}
        end

        table.insert(most, k)
    end

    if (table.contains(most, self.room:getCurrent():objectName())) then
        return table.contains(self.friends, self.room:getCurrent(), true)
    end

    for _, p in ipairs(most) do
        if (table.contains(self.enemies, p, true)) then return true end
    end
    return false
end

sgs.ai_skill_playerchosen.shifei = function(self, targets)
    targets = sgs.QList2Table(targets)
    for _, target in ipairs(targets) do
        if self:isEnemy(target) and target:isAlive() then
            return target
        end
    end
end



-- 勤王
sgs.ai_skill_cardask["@qinwang-discard"] = function(self, data)
	local cards = sgs.QList2Table(self.player:getCards("he"))
	self:sortByKeepValue(cards)
	for _, c in ipairs(cards) do
		if c:isKindOf("Slash") or c:isKindOf("Peach") or c:isKindOf("Analeptic") then
			return "."
		end
	end
	return cards[1]
end

-- zhenshan buhui!!!

-- 宴诛
yanzhu_skill = {name = "yanzhu"}
table.insert(sgs.ai_skills, yanzhu_skill)
yanzhu_skill.getTurnUseCard = function(self)

    if (self.player:hasUsed("YanzhuCard")) then return nil end

    return sgs.Card_Parse("@YanzhuCard=.")

end


sgs.ai_skill_use_func.YanzhuCard = function(card, use, self)

    self:sort(self.enemies, "threat")
    for _, p in ipairs(self.enemies) do
        if not p:isNude() then
            use.card = card
            if (use.to) then use.to:append(p) end
            -- use.from = self.player
            return
        end
    end

    for _, p in ipairs(self.friends_noself) do
        if self.needToThrowArmor(p) and p:getArmor() and not p:isJilei(p:getArmor()) then
            use.card = card
            if (use.to) then use.to:append(p) end
            -- use.from = self.player
            return
        end
    end

    return nil
end

sgs.ai_use_priority.YanzhuCard = sgs.ai_use_priority.Dismantlement - 0.1

sgs.ai_skill_discard.yanzhu = function(self, _, __, optional)
    if not optional then return self:askForDiscard("dummyreason", 1, 1, false, true) end

    if self:needToThrowArmor() and self.player:getArmor() and not self.player:isJilei(self.player:getArmor()) then return self.player:getArmor():getEffectiveId() end

    if self.player:getTreasure() then
        if (self.player:getCardCount() == 1) then return self.player:getTreasure():getEffectiveId()
        elseif not self.player:isKongcheng() then return self:askForDiscard("dummyreason", 1, 1, false, false) end
    end

    if self.player:getEquips():length() > 2 and not self.player:isKongcheng() then return self:askForDiscard("dummyreason", 1, 1, false, false) end

    if self.player:getEquips():length() == 1 then return {} end

     return self:askForDiscard("dummyreason", 1, 1, false, true)
end

-- 兴学
sgs.ai_skill_use["@@xingxue"] = function(self)

    local n = (self.player:getMark("yanzhu_lost") == 0) and self.player:getHp() or self.player:getMaxHp()

    self:sort(self.friends, "defense")

    n = math.min(n, #self.friends)

    local l = sgs.SPlayerList()
    local s = {}
    for i = 1, n, 1 do
        l:append(self.friends[i])
        table.insert(s, self.friends[i]:objectName())
    end

    if #s == 0 then return "." end

    sgs.xingxuelist = l

    return "@XingxueCard=.->" .. (table.concat(s, "+"))
end

-- 兴学剩下的部分大家想象吧，我懒得想
-- sgs.ai_skill_discard.xingxue = function(self) end

-- 樵拾
sgs.ai_skill_invoke.qiaoshi = function(self, data)
	local current = self.room:getCurrent()
	if self:isFriend(current) then return true end
	return false
end

-- 燕语
yanyu_skill = {name = "yjyanyu"}
table.insert(sgs.ai_skills, yanyu_skill)
yanyu_skill.getTurnUseCard = function(self)
    return sgs.Card_Parse("@YjYanyuCard=.")
end

sgs.ai_skill_use_func.YjYanyuCard = function(card, use, self)
    local n = self.player:getMark("yjyanyu")

    if n >= 2 then return nil end

    local ns, fs, ts = {}, {}, {}
    for _, c in sgs.qlist(self.player:getHandcards()) do
        if (c:isKindOf("Slash")) then
            n = n + 1
            if (c:isKindOf("FireSlash")) then
                table.insert(fs, c)
            elseif (c:isKindOf("ThunderSlash")) then
                table.insert(ts, c)
            else
                table.insert(ns, c)
            end
        end
    end

    if n < 2 then return nil end

    local hasmale = false
    for _, p in ipairs(self.friends_noself) do
        if (p:isMale()) then
            hasmale = true
            break
        end
    end

    if not hasmale then return nil end

    local id = nil
    if #ns > 0 then
        id = ns[1]:getEffectiveId()
    elseif #ts > 0 then
        id = ts[1]:getEffectiveId()
    elseif #fs > 0 then
        id  = fs[1]:getEffectiveId()
    end

    if not id then return nil end

    use.card = sgs.Card_Parse("@YjYanyuCard=" .. tostring(id))
end

sgs.ai_skill_playerchosen.yjyanyu = function(self)

    self:sort(self.friends_noself, "handcard")

    for i = #self.friends_noself, 1, -1 do
        if self.friends_noself[i]:isMale() then
            return self.friends_noself[i]
        end
    end

    return nil
end

sgs.ai_use_priority.YjYanyuCard = sgs.ai_use_priority.Slash - 0.01

sgs.ai_cardneed.yanyu = sgs.ai_cardneed.lieren
-- furong 懒得想
--[[
furong_skill = {name = "furong"}
table.insert(sgs.ai_skills, furong_skill)
furong_skill.getTurnUseCard = function(self)
    return nil
end

sgs.ai_skill_use_func.FurongCard = function(card, use, self)

end
]]
-- sgs.ai_skill_discard.furong = function(self) end

-- huomo buhui !!!
-- sgs.ai_cardsview_valuable.huomo = function() end
--[[
huomo_skill = {name = "huomo"}
table.insert(sgs.ai_skills, huomo_skill)
huomo_skill.getTurnUseCard = function(self)
    return nil
end

sgs.ai_skill_use_func.HuomoCard = function(card, use, self) end
]]

-- 佐定
sgs.ai_skill_playerchosen.zuoding = function(self, targets)
    local l = {}
    for _, p in sgs.qlist(targets) do
        if table.contains(self.friends, p, true) then
            table.insert(l, p)
        end
    end

    if #l == 0 then return nil end

    self:sort(l, "defense")
    return l[#l]
end

-- 安国
anguo_skill = {name = "anguo"}
table.insert(sgs.ai_skills, anguo_skill)
anguo_skill.getTurnUseCard = function(self)
    if (not self.player:hasUsed("AnguoCard")) then
        return sgs.Card_Parse("@AnguoCard=.")
    end

    return nil
end

sgs.ai_skill_use_func.AnguoCard = function(card, use, self)
    local l = {}
    function calculateMinus(player, range)
        if range <= 0 then return 0 end
        local n = 0
        for _, p in sgs.qlist(self.room:getAlivePlayers()) do
            if player:inMyAttackRange(p) and not player:inMyAttackRange(p, range) then n = n + 1 end
        end
        return n
    end

    function filluse(to, id)
        use.card = card
        if (use.to) then use.to:append(to) end
        self.anguoid = id
    end

    for _, p in ipairs(self.enemies) do
        if (p:getWeapon()) then
            local weaponrange = p:getWeapon():getRealCard():toWeapon():getRange()
            local n = calculateMinus(p, weaponrange - 1)
            table.insert(l, {player = p, id = p:getWeapon():getEffectiveId(), minus = n})
        end
        if (p:getOffensiveHorse()) then
            local n = calculateMinus(p, 1)
            table.insert(l, {player = p, id = p:getOffensiveHorse():getEffectiveId(), minus = n})
        end
    end

    if #l > 0 then
        function sortByMinus(a, b)
            return a.minus > b.minus
        end

        table.sort(l, sortByMinus)
        if l[1].minus > 0 then
            filluse(l[1].player, l[1].id)
            return
        end
    end

    for _, p in ipairs(self.enemies) do
        if (p:getTreasure()) then
            filluse(p, p:getTreasure():getEffectiveId())
            return
        end
    end

    for _, p in ipairs(self.friends_noself) do
        if (self:needToThrowArmor(p) and p:getArmor()) then
            filluse(p, p:getArmor():getEffectiveId())
            return
        end
    end

    self:sort(self.enemies, "threat")
    for _, p in ipairs(self.enemies) do
        if (p:getArmor() and not p:getArmor():isKindOf("GaleShell")) then
            filluse(p, p:getArmor():getEffectiveId())
            return
        end
    end

    for _, p in ipairs(self.enemies) do
        if (p:getDefensiveHorse()) then
            filluse(p, p:getDefensiveHorse():getEffectiveId())
            return
        end
    end
end

sgs.ai_use_priority.AnguoCard = sgs.ai_use_priority.ExNihilo + 0.01

sgs.ai_skill_cardchosen.anguo = function(self)
    return self.anguoid
end
