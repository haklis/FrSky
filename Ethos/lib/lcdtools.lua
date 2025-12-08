local lcdtools = {}

function lcdtools.gradient(x, y, w, h, color1, color2)
    r1 = math.floor(color1 / 32 / 64) % 32 * 8
    g1 = math.floor(color1 / 32) % 64 * 4
    b1 = color1 % 32 * 8

    r2 = math.floor(color2 / 32 / 64) % 32 * 8
    g2 = math.floor(color2 / 32) % 64 * 4
    b2 = color2 % 32 * 8

    dr = (r2 - r1) / w
    dg = (g2 - g1) / w
    db = (b2 - b1) / w

    colorStep = color2 - color1

    for i=0, w, 1 do
        r = math.floor(r1 + (dr * i))
        g = math.floor(g1 + (dg * i))
        b = math.floor(b1 + (db * i))
   
        lcd.color(lcd.RGB(r,g,b))
        lcd.drawLine(x+i,y,x+i,y+h)
    end
end
return lcdtools