﻿lia.currency = lia.currency or {}
lia.currency.symbol = lia.config.get("CurrencySymbol") or ""
lia.currency.singular = lia.config.get("CurrencySingularName") or "dollar"
lia.currency.plural = lia.config.get("CurrencyPluralName") or "dollars"
function lia.currency.get(amount)
    return lia.currency.symbol .. (amount == 1 and "1 " .. lia.currency.singular or amount .. " " .. lia.currency.plural)
end

if SERVER then
    function lia.currency.spawn(pos, amount, angle)
        if not pos then
            LiliaInformation("[Lilia] Can't create currency entity: Invalid Position")
        elseif not amount or amount < 0 then
            LiliaInformation("[Lilia] Can't create currency entity: Invalid Amount of money")
        else
            local money = ents.Create("lia_money")
            money:SetPos(pos)
            money:setAmount(math.Round(math.abs(amount)))
            money:SetAngles(angle or Angle(0, 0, 0))
            money:Spawn()
            money:Activate()
            return money
        end
    end
end
