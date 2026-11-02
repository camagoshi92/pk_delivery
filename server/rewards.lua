-- Calcolo e consegna delle ricompense. Tutto deciso qui: il client non invia mai importi.
local Texts = Config.Texts

local function roundMoney(value)
    return math.floor(value * 100 + 0.5) / 100
end

local function rollMoney(money)
    local minimum = math.floor((money.Min or 0) * 100)
    local maximum = math.floor((money.Max or money.Min or 0) * 100)
    if maximum < minimum then
        minimum, maximum = maximum, minimum
    end
    return math.random(minimum, maximum) / 100
end

local function timeBonusPercent(bonus, elapsed)
    if not bonus or not bonus.Enabled or not elapsed then
        return 0
    end
    return elapsed <= bonus.TargetSeconds and bonus.Percent or 0
end

local function payMoney(src, reward, options, lines)
    local money = reward.Money
    if not money then return end

    local amount = rollMoney(money)
    local bonus = timeBonusPercent(reward.TimeBonus, options.elapsed)
    amount = roundMoney(amount * (1 + bonus / 100) * (options.multiplier or 1.0))
    if amount <= 0 then return end

    local currency = money.Currency or 'cash'
    if not Bridge.SupportsCurrency(currency) then
        currency = 'cash'
    end

    if Bridge.AddMoney(src, amount, currency) then
        lines[#lines + 1] = (currency == 'gold' and Texts.RewardGold or Texts.RewardMoney):format(amount)
        if bonus > 0 then
            lines[#lines + 1] = Texts.RewardBonus:format(bonus)
        end
    end
end

local function handleFullInventory(src, entry, count, lines)
    if Config.InventoryFull ~= 'money' or not entry.FallbackPrice then
        lines[#lines + 1] = Texts.InventoryFullLost:format(entry.Name)
        return
    end

    local amount = roundMoney(entry.FallbackPrice * count)
    if Bridge.AddMoney(src, amount, 'cash') then
        lines[#lines + 1] = Texts.InventoryFullMoney:format(entry.Name, amount)
    end
end

local function giveItems(src, reward, lines)
    for _, entry in ipairs(reward.Items or {}) do
        if entry.Name and entry.Name ~= '' and math.random(1, 100) <= (entry.Chance or 100) then
            local count = math.random(entry.Min or 1, entry.Max or entry.Min or 1)
            if Bridge.CanCarry(src, entry.Name, count) and Bridge.AddItem(src, entry.Name, count) then
                lines[#lines + 1] = Texts.RewardItem:format(count, entry.Name)
            else
                handleFullInventory(src, entry, count, lines)
            end
        end
    end
end

-- options = { elapsed = secondi per il bonus tempo, multiplier = quota del carico rimasta }
function Delivery.GiveReward(src, reward, label, options)
    reward = reward or {}
    local mode = reward.Mode or 'money'
    local lines = {}

    if mode == 'money' or mode == 'both' then
        payMoney(src, reward, options or {}, lines)
    end

    if mode == 'items' or mode == 'both' then
        giveItems(src, reward, lines)
    end

    UI.Notify(src, 'success', #lines > 0 and table.concat(lines, ' ') or Texts.RewardNone, label)
end
