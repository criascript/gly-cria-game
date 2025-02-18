local speeches = {
    "javascript é muitu bom!",
    "vem pro foguetinho meu!",
    "faz meu curso p vc ganhar mais de 6k!",
    "javascript é bom",
    "seja um dev fullstack em 3 meses!",
    "vc vai ganhar em dólar!",
    "faz o pix que eu te ensino!"
}

local function init_platforms(std, game)
    table.insert(game.platforms, {
        x = 0,
        y = game.height - game.PLATFORM_CONFIGS[1].y_offset,
        width = game.width,
        height = game.PLATFORM_CONFIGS[1].y_offset,
        level = 1,
        color = game.PLATFORM_CONFIGS[1].color
    })
    
    local config2 = game.PLATFORM_CONFIGS[2]
    for i = 1, config2.count do
        table.insert(game.platforms, {
            x = game.width * i/4,
            y = game.height - config2.y_offset,
            width = config2.width,
            height = 20,
            level = 3,
            color = config2.color
        })
    end
    
    local config3 = game.PLATFORM_CONFIGS[3]
    for i = 1, config3.count do
        table.insert(game.platforms, {
            x = game.width * i/3,
            y = game.height - config3.y_offset,
            width = config3.width,
            height = 20,
            level = 3,
            color = config3.color
        })
    end
end


local function init(std, game)
    if not game then 
        error("Game object is nil during initialization") 
    end

    game.state = 1
    game.score = 0
    game.kills = 0
    game.lives = 3
    game.enemy_color_index = 0
    game.difficulty_level = 1
    game.time_alive = 0

    if not std or not std.color then
        error("Standard library or color object is missing")
    end

    game.ENEMY_TYPES = {
        RUNNER = {
            speed = 2, 
            attack_type = "chase",
            color = std.color.red or {r=255,g=0,b=0},
            damage = 1,
            jump_force = -6 
        },
        JUMPER = {
            speed = 3,  
            attack_type = "jump",
            color = std.color.green or {r=0,g=255,b=0},
            damage = 2,
            jump_interval = 500,  
            jump_force = -10  
        },
        SHOOTER = {
            speed = 2,
            attack_type = "shoot",
            color = std.color.purple or {r=128,g=0,b=128},
            damage = 1,
            shoot_interval = 200
        },
        BOSS = {
            speed = 2,
            attack_type = "multi",
            color = std.color.black or {r=0,g=0,b=0},
            damage = 3,
            attack_interval = 3000,
            health = 3
        }
    }
    
    game.PLATFORM_CONFIGS = {
        {
            level = 1,
            y_offset = 60,
            width = "full",
            color = std.color.green or {r=0,g=255,b=0}
        },
        {
            level = 2,
            y_offset = 160,   
            width = 150,      
            count = 3,
            color = std.color.brown or {r=165,g=42,b=42}
        },
        {
            level = 3,
            y_offset = 260,   
            width = 170,      
            count = 2,
            color = std.color.gray or {r=128,g=128,b=128}
        }
    }
    
    game.player = {
        x = game.width/4 or 100,
        y = game.height - 100 or 300,
        width = 40,
        height = 40,
        speed_x = 0,
        speed_y = 0,
        jumping = false,
        can_double_jump = true,
        has_double_jumped = false,
        gravity = 0.03,          
        jump_force = -15,        
        ground_y = game.height - 100 or 300,
        facing_right = true,
        animation_state = "idle",
        animation_timer = 0
    }
    
    game.bananas = game.bananas or {}
    game.enemies = game.enemies or {}
    game.bullets = game.bullets or {}
    game.platforms = game.platforms or {}
    
    game.banana_spawn_timer = 0
    game.enemy_spawn_timer = 0
    game.spawn_pattern_index = 0
    game.accumulated_time = 0
    game.animation_time = 0
    game.banana_time = 0
    game.enemy_time = 0
    
    game.GAME_SPEED = 0.5          
    game.ENEMY_SPAWN_RATE = 4000   
    game.BULLET_SPEED = 3          
    game.BANANA_SPAWN_RATE = 4000  
    
    game.spawn_heights = {}
    for i = 1, 5 do
        table.insert(game.spawn_heights, game.height - (150 + i * 50))
    end
    
    init_platforms(std, game)

end

local function handle_player_movement(std, game)
    local p = game.player
    
    p.speed_x = std.key.axis.x * 4
    
    if p.speed_x ~= 0 then
        p.facing_right = p.speed_x > 0
        p.animation_state = "walking"
    else
        p.animation_state = "idle"
    end
    
    if std.key.axis.y == -1 then
        if not p.jumping then
            p.speed_y = p.jump_force
            p.jumping = true
            p.can_double_jump = true
            p.animation_state = "jumping"
        elseif p.can_double_jump and not p.has_double_jumped then
            p.speed_y = p.jump_force * 0.9  
            p.has_double_jumped = true
            p.can_double_jump = false
            p.animation_state = "double_jumping"
        end
    end
    
    p.speed_y = p.speed_y + (p.gravity * std.delta)
    p.x = p.x + (p.speed_x) 
    p.y = p.y + (p.speed_y) 
    
    local on_ground = false
    for _, platform in ipairs(game.platforms) do
        if p.y + p.height >= platform.y and
           p.y < platform.y + platform.height and
           p.x + p.width > platform.x and
           p.x < platform.x + platform.width then
            if p.speed_y > 0 then 
                p.y = platform.y - p.height
                p.speed_y = 0
                p.jumping = false
                p.has_double_jumped = false
                on_ground = true
                if p.animation_state == "jumping" or p.animation_state == "double_jumping" then
                    p.animation_state = "idle"
                end
            end
        end
    end
    
    p.x = std.math.clamp(p.x, 0, game.width - p.width)
    if p.y > game.height then
        game.lives = math.max(0, (tonumber(game.lives) or 3) - 1)
        
        if game.lives <= 0 then
            game.state = 2  
        else
            p.y = game.height/2
            p.speed_y = 0
        end
    end
    
    game.animation_time = game.animation_time + std.delta
    if game.animation_time > 100 then
        game.animation_time = 0
    end
end

local function update_platforms(std, game)
    for i = #game.platforms, 1, -1 do
        local platform = game.platforms[i]
        if platform.level > 1 then  
            platform.x = platform.x - (2 * game.GAME_SPEED * std.delta)
            
            if platform.x + platform.width < 0 then
                table.remove(game.platforms, i)
            end
        end
    end
    
    local platforms_needed = {
        [2] = game.PLATFORM_CONFIGS[2].count,
        [3] = game.PLATFORM_CONFIGS[3].count
    }
    
    local platform_counts = {[2] = 0, [3] = 0}
    for _, platform in ipairs(game.platforms) do
        if platform.level > 1 then
            platform_counts[platform.level] = platform_counts[platform.level] + 1
        end
    end
    
    for level = 2, 3 do
        if platform_counts[level] < platforms_needed[level] then
            local config = game.PLATFORM_CONFIGS[level]
            table.insert(game.platforms, {
                x = game.width + 50,  
                y = game.height - config.y_offset,
                width = config.width,
                height = 20,
                level = level,
                color = config.color
            })
        end
    end
end


local function update_game_speed(std, game)
    game.accumulated_time = game.accumulated_time + std.delta
    
    game.GAME_SPEED = 0.05 + (game.accumulated_time / 60000) 
    
    game.GAME_SPEED = std.math.clamp(game.GAME_SPEED, 0.05, 2.0)

    game.BANANA_SPAWN_RATE = 2000 / game.GAME_SPEED
    game.ENEMY_SPAWN_RATE = 4000 / game.GAME_SPEED
    game.BULLET_SPEED = 3 * game.GAME_SPEED
end

local function spawn_banana(std, game)
    game.banana_time = game.banana_time + std.delta
    
    if game.banana_time > (game.BANANA_SPAWN_RATE * 0.3) and #game.platforms > 0 then
        local banana_count = 1 + (std.milis % 3) 
        
        for _ = 1, banana_count do
            local platform_index = (std.milis % #game.platforms) + 1
            local platform = game.platforms[platform_index]
            
            if platform then
                local y = platform.y - 30  
                
                local x_offset = (std.milis % 100) - 50
                
                table.insert(game.bananas, {
                    x = game.width + x_offset, 
                    y = y,
                    width = 35,
                    height = 20,
                    platform = platform
                })
            end
        end
        
        game.banana_spawn_timer = std.milis
        game.banana_time = 0
    end
end

local function spawn_banana(std, game)
    game.banana_time = game.banana_time + std.delta
    
    if game.banana_time > game.BANANA_SPAWN_RATE and #game.platforms > 0 then
        local platform_index = (std.milis % #game.platforms) + 1
        local platform = game.platforms[platform_index]
        
        if platform then
            local y = platform.y - 30 
            
            table.insert(game.bananas, {
                x = game.width,
                y = y,
                width = 35,
                height = 20,
                platform = platform
            })
        end
        game.banana_spawn_timer = std.milis
        game.banana_time = 0
    end
end

local function spawn_enemy(std, game)
    game.enemy_time = game.enemy_time + std.delta
    
    if game.enemy_time > game.ENEMY_SPAWN_RATE and #game.platforms > 0 then
        local platform_index = (std.milis % #game.platforms) + 1
        local platform = game.platforms[platform_index]
        
        if not platform then return end 
        
        local enemy_types = {"RUNNER", "SHOOTER", "JUMPER"}
        if game.score > 1000 then
            table.insert(enemy_types, "BOSS")
        end
        
        local type_index = (std.milis % #enemy_types) + 1
        local enemy_type_name = enemy_types[type_index]
        local enemy_type = game.ENEMY_TYPES[enemy_type_name]
        
        if not enemy_type then return end 
        
        local enemy = {
            x = game.width - 50,
            y = platform.y - 40,
            width = 40,
            height = 40,
            type = enemy_type_name,
            properties = enemy_type,
            speed = enemy_type.speed * 0.2, 
            direction = -1,
            last_shot = std.milis,
            last_jump = std.milis,
            health = enemy_type.health or 1,
            animation_state = "walking",
            animation_timer = 0,
            platform = platform,
            speed_y = 0,
            speech = speeches[(std.milis % #speeches) + 1],
            show_speech = false,
            speech_timer = std.milis + 1000 + (std.milis % 2000)
        }
        
        table.insert(game.enemies, enemy)
        game.enemy_time = 0
    end
end

local function update_enemy(std, game, enemy)
    if not game or not enemy then return true end

    enemy.show_speech = std.milis > enemy.speech_timer and std.milis < enemy.speech_timer + 3000
    enemy.animation_timer = (enemy.animation_timer + std.delta) % 100
    
    local movement_x = (enemy.speed * enemy.direction * std.delta) - (2 * game.GAME_SPEED * std.delta)
    enemy.x = enemy.x + movement_x
    
    enemy.speed_y = (enemy.speed_y or 0) + (game.player.gravity * std.delta)
    enemy.y = enemy.y + (enemy.speed_y * std.delta)
    
    local current_platform = enemy.platform
    local next_platform = nil
    local can_jump = false
    local landed = false
    
    local dist_to_player = std.math.abs(enemy.x - game.player.x)
    local player_direction = enemy.x > game.player.x and -1 or 1
    local player_in_range = dist_to_player < 400
    
    for _, platform in ipairs(game.platforms) do
        if enemy.y + enemy.height >= platform.y and
           enemy.y + enemy.height < platform.y + platform.height and
           enemy.x + enemy.width > platform.x and
           enemy.x < platform.x + platform.width then
            enemy.y = platform.y - enemy.height
            enemy.speed_y = 0
            enemy.platform = platform
            landed = true
            
            for _, next_plat in ipairs(game.platforms) do
                if next_plat ~= platform and 
                   next_plat.level >= platform.level and
                   ((enemy.direction > 0 and next_plat.x > platform.x + platform.width) or
                    (enemy.direction < 0 and next_plat.x + next_plat.width < platform.x)) then
                    next_platform = next_plat
                    break
                end
            end
            
            if next_platform and 
               std.math.abs(enemy.x - platform.x - platform.width/2) > platform.width/2 then
                can_jump = true
            end
            
            break
        end
    end
    
    if not landed then
        enemy.animation_state = "jumping"
    elseif enemy.type ~= "SHOOTER" then
        enemy.animation_state = "walking"
    end
    
    if enemy.type == "RUNNER" then
        if dist_to_player < 300 then
            enemy.direction = player_direction
            
            if dist_to_player < 100 then
                enemy.speed = enemy.properties.speed * 1.5 * game.GAME_SPEED
            else
                enemy.speed = enemy.properties.speed * game.GAME_SPEED
            end
            
            enemy.animation_state = "running"
        else
            enemy.speed = enemy.properties.speed * 0.5 * game.GAME_SPEED
            enemy.animation_state = landed and "walking" or "jumping"
        end
        
        if can_jump and std.milis > enemy.last_jump + 1500 and landed then
            enemy.speed_y = enemy.properties.jump_force * 0.7
            enemy.last_jump = std.milis
            enemy.animation_state = "jumping"
        end
        
    elseif enemy.type == "SHOOTER" then
        if player_in_range and landed then
            enemy.speed = 0
            enemy.animation_state = "shooting"
            
            if std.milis > enemy.last_shot + enemy.properties.shoot_interval * 2 then
                local dir = enemy.x > game.player.x and -1 or 1
                
                local angle = std.math.clamp(
                    (game.player.y - enemy.y) / std.math.abs(game.player.x - enemy.x),
                    -0.5, 0.5
                )
                
                table.insert(game.bullets, {
                    x = enemy.x + (dir > 0 and enemy.width or 0),
                    y = enemy.y + enemy.height/2,
                    speed = game.BULLET_SPEED * dir,
                    damage = enemy.properties.damage,
                    color = enemy.properties.color
                })
                enemy.last_shot = std.milis
            end
        else
            enemy.speed = enemy.properties.speed * 0.5 * game.GAME_SPEED
            enemy.animation_state = landed and "walking" or "jumping"
        end
        
    elseif enemy.type == "JUMPER" then
        if dist_to_player < 300 then
            enemy.direction = player_direction
            enemy.speed = enemy.properties.speed * game.GAME_SPEED
            
            if (landed and std.milis > enemy.last_jump + 2000) or
               (next_platform and std.math.abs(enemy.x - game.player.x) < 200) then
                local jump_modifier = std.math.clamp(dist_to_player / 300, 0.5, 0.7)
                enemy.speed_y = enemy.properties.jump_force * jump_modifier
                
                enemy.speed_y = std.math.max(enemy.speed_y, -10)
                
                enemy.last_jump = std.milis
                enemy.animation_state = "jumping"
            end
        else
            enemy.speed = enemy.properties.speed * 0.5 * game.GAME_SPEED
            enemy.animation_state = landed and "walking" or "jumping"
        end
        
    elseif enemy.type == "BOSS" then
        if dist_to_player < 400 then
            enemy.direction = player_direction
            enemy.speed = enemy.properties.speed * game.GAME_SPEED
            
            if std.milis > enemy.last_shot + enemy.properties.attack_interval then
                for i = -1, 1 do
                    table.insert(game.bullets, {
                        x = enemy.x + (enemy.direction > 0 and enemy.width or 0),
                        y = enemy.y + enemy.height/2 + (i * 20),
                        speed = game.BULLET_SPEED * enemy.direction,
                        damage = enemy.properties.damage,
                        color = enemy.properties.color
                    })
                end
                enemy.last_shot = std.milis
            end
        else
            enemy.speed = enemy.properties.speed * 0.5 * game.GAME_SPEED
        end
    end
    
    return enemy.x + enemy.width < 0 or enemy.x > game.width + 100
end

local function update_objects(std, game)
    update_game_speed(std, game)
    update_platforms(std, game)
    
    for i = #game.bananas, 1, -1 do
        local banana = game.bananas[i]
        banana.x = banana.x - (3 * game.GAME_SPEED * std.delta)
        
        if std.math.dis(game.player.x + game.player.width/2, 
                       game.player.y + game.player.height/2,
                       banana.x + banana.width/2,
                       banana.y + banana.height/2) < 30 then
            game.score = game.score + 1
            game.GAME_SPEED = game.GAME_SPEED + 0.1
            table.remove(game.bananas, i)
        elseif banana.x + banana.width < 0 then
            table.remove(game.bananas, i)
        end
    end
    
    for i = #game.enemies, 1, -1 do
        local enemy = game.enemies[i]
        local remove_enemy = update_enemy(std, game, enemy)
        
        if game.player.x + game.player.width > enemy.x and
           game.player.x < enemy.x + enemy.width and
           game.player.y + game.player.height > enemy.y and
           game.player.y < enemy.y + enemy.height then
            
            if game.player.speed_y <= 0 then
                local damage = tonumber(enemy.properties.damage) or 1
                game.lives = math.max(0, (tonumber(game.lives) or 3) - damage)
                
                if game.lives <= 0 then
                    game.state = 2 
                end
            end
        end
        
        if game.player.speed_y > 0 and
           game.player.x + game.player.width > enemy.x and
           game.player.x < enemy.x + enemy.width and
           game.player.y + game.player.height > enemy.y and
           game.player.y < enemy.y + enemy.height then
            
            enemy.health = math.max(0, (tonumber(enemy.health) or 1) - 1)
            game.kills = game.kills + (enemy.health <= 0 and 1 or 0)
            
            game.player.speed_y = -8
            game.player.jumping = true
            game.player.has_double_jumped = false
            game.player.can_double_jump = true
            
            if enemy.health <= 0 then
                remove_enemy = true
            end
        end
        
        if remove_enemy then
            table.remove(game.enemies, i)
        end
    end
    
    for i = #game.bullets, 1, -1 do
        local bullet = game.bullets[i]
        bullet.x = bullet.x + (bullet.speed * std.delta)
        
        if game.player.x + game.player.width > bullet.x and
           game.player.x < bullet.x + 10 and
           game.player.y + game.player.height > bullet.y and
           game.player.y < bullet.y + 10 then
            
            local damage = tonumber(bullet.damage) or 1
            game.lives = math.max(0, (tonumber(game.lives) or 3) - damage)
            
            if game.lives <= 0 then
                game.state = 2
            end
            table.remove(game.bullets, i)
        elseif bullet.x < 0 or bullet.x > game.width then
            table.remove(game.bullets, i)
        end
    end
end

local function draw_banana(std, x, y)
    std.draw.color(std.color.yellow)
    std.draw.rect(0, x + 5, y, 25, 15)
    
    std.draw.color(std.color.brown)
    std.draw.rect(0, x, y + 5, 5, 5)
    std.draw.rect(0, x + 30, y + 5, 5, 5)
end

local function draw_cs_logo(std, x, y)
    std.draw.color(std.color.black)
    
    std.draw.rect(0, x - 2, y, 2, 10)     
    std.draw.rect(0, x - 2, y, 7, 2)      
    std.draw.rect(0, x - 2, y + 8, 7, 2)  
    
    std.draw.rect(0, x + 7, y, 7, 2)      
    std.draw.rect(0, x + 7, y + 4, 7, 2)  
    std.draw.rect(0, x + 7, y + 8, 7, 2)  
    std.draw.rect(0, x + 7, y, 2, 5)      
    std.draw.rect(0, x + 12, y + 5, 2, 5)  
end

local function draw_enemy(std, game, enemy)
    local facing_right = enemy.direction > 0
    local animation_offset = enemy.animation_timer > 5 and 2 or 0
    
    std.draw.color(std.color.black)
    if enemy.animation_state == "walking" or enemy.animation_state == "running" then
        std.draw.rect(0, enemy.x + (facing_right and 5 or 15), enemy.y + 30 + animation_offset, 10, 10)
        std.draw.rect(0, enemy.x + (facing_right and 25 or 35), enemy.y + 30 - animation_offset, 10, 10)
    else
        std.draw.rect(0, enemy.x + (facing_right and 5 or 15), enemy.y + 30, 10, 10)
        std.draw.rect(0, enemy.x + (facing_right and 25 or 35), enemy.y + 30, 10, 10)
    end
    
    if enemy.type == "RUNNER" then
        std.draw.color(enemy.properties.color)
        std.draw.rect(0, enemy.x + 10, enemy.y + 10, 30, 20)
        std.draw.rect(0, enemy.x + (facing_right and 0 or 40), enemy.y + 10, 10, 10)
        
        std.draw.color(std.color.white)
        std.draw.rect(0, enemy.x + (facing_right and 15 or 25), enemy.y + 5, 8, 4)
        std.draw.color(std.color.red)
        std.draw.rect(0, enemy.x + (facing_right and 18 or 28), enemy.y + 6, 4, 2)
        
    elseif enemy.type == "SHOOTER" then
        std.draw.color(enemy.properties.color)
        std.draw.rect(0, enemy.x + 10, enemy.y + 10, 30, 20)
        
        if enemy.animation_state == "shooting" then
            std.draw.color(std.color.orange)
            std.draw.rect(0, enemy.x + (facing_right and 45 or -15), enemy.y + 15, 20, 10)
        else
            std.draw.color(std.color.black)
            std.draw.rect(0, enemy.x + (facing_right and 45 or -5), enemy.y + 15, 10, 10)
        end
        
        std.draw.color(std.color.blue)
        std.draw.rect(0, enemy.x + (facing_right and 15 or 25), enemy.y + 5, 15, 3)
        
    elseif enemy.type == "JUMPER" then
        std.draw.color(enemy.properties.color)
        std.draw.rect(0, enemy.x + 10, enemy.y + 10, 30, 20)
        
        std.draw.color(std.color.gray)
        local spring_height = enemy.animation_state == "jumping" and 20 or 15
        std.draw.rect(0, enemy.x + 5, enemy.y + 25, 10, spring_height)
        std.draw.rect(0, enemy.x + 35, enemy.y + 25, 10, spring_height)
        
    elseif enemy.type == "BOSS" then
        std.draw.color(enemy.properties.color)
        std.draw.rect(0, enemy.x + 5, enemy.y + 5, 40, 30)
        
        std.draw.color(std.color.yellow)
        local crown_offset = enemy.animation_timer > 5 and 2 or 0
        std.draw.rect(0, enemy.x + 15, enemy.y - 5 - crown_offset, 5, 5)
        std.draw.rect(0, enemy.x + 25, enemy.y - 5 - crown_offset, 5, 5)
        std.draw.rect(0, enemy.x + 35, enemy.y - 5 - crown_offset, 5, 5)
        
        std.draw.color(std.color.red)
        std.draw.rect(0, enemy.x + (facing_right and 15 or 25), enemy.y + 10, 8, 8)
    end
end

local function draw_speech_bubble(std, x, y, text)
    if not text then return end
    
    std.text.font_size(40)
    local text_width = std.text.mensure(text) or 400
    local bubble_width = text_width + 80
    local bubble_height = 100
    
    local bubble_x = x - bubble_width/2 + 20
    local bubble_y = y - 150
    
    std.draw.color(std.color.white)
    std.draw.rect(0, bubble_x, bubble_y, bubble_width, bubble_height)
    
    std.draw.rect(0, bubble_x + bubble_width/2 - 10, bubble_y + bubble_height, 20, 15)
    
    std.draw.color(std.color.black)
    std.text.print(bubble_x + 40, bubble_y + 30, text)
    
    std.draw.line(bubble_x, bubble_y, bubble_x + bubble_width, bubble_y)
    std.draw.line(bubble_x, bubble_y + bubble_height, bubble_x + bubble_width, bubble_y + bubble_height)
    std.draw.line(bubble_x, bubble_y, bubble_x, bubble_y + bubble_height)
    std.draw.line(bubble_x + bubble_width, bubble_y, bubble_x + bubble_width, bubble_y + bubble_height)
end


local function draw_big_pixel_heart(std, x, y, filled)
    if not std or not std.draw or not std.draw.color or not std.draw.rect then
        return
    end

    filled = not not filled

    if filled then
        std.draw.color(std.color.red or {r=255, g=0, b=0})
    else
        std.draw.color(std.color.dark_gray or {r=169, g=169, b=169})
    end

    std.draw.rect(0, x + 2, y, 6, 4)
    std.draw.rect(0, x + 10, y, 6, 4)
    std.draw.rect(0, x, y + 4, 18, 4)
    std.draw.rect(0, x + 2, y + 8, 14, 4)
    std.draw.rect(0, x + 4, y + 12, 10, 4)
    std.draw.rect(0, x + 6, y + 16, 6, 4)
end


local pixel_letters = {
    B = {
        {1,1,1},
        {1,0,1},
        {1,1,1},
        {1,0,1},
        {1,1,1}
    },
    A = {
        {0,1,0},
        {1,0,1},
        {1,1,1},
        {1,0,1},
        {1,0,1}
    },
    N = {
        {1,0,1},
        {1,1,1},
        {1,0,1},
        {1,0,1},
        {1,0,1}
    },
    V = {
        {1,0,1},
        {1,0,1},
        {1,0,1},
        {0,1,0},
        {0,1,0}
    },
    E = {
        {1,1,1},
        {1,0,0},
        {1,1,0},
        {1,0,0},
        {1,1,1}
    },
    D = {
        {1,1,0},
        {1,0,1},
        {1,0,1},
        {1,0,1},
        {1,1,0}
    },
    O = {
        {0,1,0},
        {1,0,1},
        {1,0,1},
        {1,0,1},
        {0,1,0}
    },
    R = {
        {1,1,0},
        {1,0,1},
        {1,1,0},
        {1,1,0},
        {1,0,1}
    },
    S = {
        {0,1,1},
        {1,0,0},
        {0,1,0},
        {0,0,1},
        {1,1,0}
    },
    I = {
        {1,1,1},
        {0,1,0},
        {0,1,0},
        {0,1,0},
        {1,1,1}
    },
    H = {
        {1,0,1},
        {1,0,1},
        {1,1,1},
        {1,0,1},
        {1,0,1}
    }
}

local function draw_pixel_letter(std, x, y, letter)
    local upper_letter = string.upper(tostring(letter))
    local letter_data = pixel_letters[upper_letter]
    
    if not std or not std.draw or not std.draw.color or not std.draw.rect then 
        return 
    end

    if not letter_data then return end
    
    std.draw.color(std.color.white or {r=255, g=255, b=255})

    local size = 4  
    for i = 1, #letter_data do
        for j = 1, #letter_data[i] do
            if letter_data[i][j] == 1 then
                std.draw.rect(0, x + (j - 1) * size, y + (i - 1) * size, size, size)
            end
        end
    end
end

local function draw_pixel_text(std, x, y, text)
    if not std or not text then return end

    local spacing = 14
    local safe_text = tostring(text)
    
    for i = 1, #safe_text do
        local letter = safe_text:sub(i, i)
        draw_pixel_letter(std, x + (i - 1) * spacing, y, letter)
    end
end

local pixel_numbers = {
    ["0"] = {
        {1,1,1},
        {1,0,1},
        {1,0,1},
        {1,0,1},
        {1,1,1}
    },
    ["1"] = {
        {0,1,0},
        {1,1,0},
        {0,1,0},
        {0,1,0},
        {1,1,1}
    },
    ["2"] = {
        {1,1,1},
        {0,0,1},
        {1,1,1},
        {1,0,0},
        {1,1,1}
    },
    ["3"] = {
        {1,1,1},
        {0,0,1},
        {0,1,1},
        {0,0,1},
        {1,1,1}
    },
    ["4"] = {
        {1,0,1},
        {1,0,1},
        {1,1,1},
        {0,0,1},
        {0,0,1}
    },
    ["5"] = {
        {1,1,1},
        {1,0,0},
        {1,1,1},
        {0,0,1},
        {1,1,1}
    },
    ["6"] = {
        {1,1,1},
        {1,0,0},
        {1,1,1},
        {1,0,1},
        {1,1,1}
    },
    ["7"] = {
        {1,1,1},
        {0,0,1},
        {0,1,0},
        {1,0,0},
        {1,0,0}
    },
    ["8"] = {
        {1,1,1},
        {1,0,1},
        {1,1,1},
        {1,0,1},
        {1,1,1}
    },
    ["9"] = {
        {1,1,1},
        {1,0,1},
        {1,1,1},
        {0,0,1},
        {1,1,1}
    }
}

local function draw_pixel_digit(std, x, y, digit)
    local digit_data = pixel_numbers[tostring(digit)]
    if not digit_data then return end

    if not std or not std.draw or not std.draw.color or not std.draw.rect then 
        return 
    end

    std.draw.color(std.color.yellow or {r=255, g=255, b=0})

    local size = 4  
    for i = 1, #digit_data do
        for j = 1, #digit_data[i] do
            if digit_data[i][j] == 1 then
                std.draw.rect(0, x + (j - 1) * size, y + (i - 1) * size, size, size)
            end
        end
    end
end

local function draw_pixel_number(std, x, y, number)
    if not std or not number then return end

    local num_str = tostring(math.floor(tonumber(number) or 0))
    
    local spacing = 14
    for i = 1, #num_str do
        local digit = num_str:sub(i, i)
        draw_pixel_digit(std, x + (i - 1) * spacing, y, digit)
    end
end

local function draw_hud(std, game)
    if not std or not game then return end
    
    if not std.draw or not std.draw.color or not std.draw.rect then 
        return 
    end

    local width = tonumber(game.width) or 800
    width = math.max(width, 100)

    std.draw.color(std.color.black or {r=0,g=0,b=0})
    std.draw.rect(0, 0, 0, width, 60)

    std.draw.color(std.color.gray or {r=128,g=128,b=128})
    std.draw.rect(0, 4, 4, width - 8, 52)

    std.draw.color(std.color.dark_gray or {r=169,g=169,b=169})
    std.draw.rect(0, 4, 4, width - 8, 3)
    std.draw.rect(0, 4, 53, width - 8, 3)
    std.draw.rect(0, 4, 4, 3, 52)
    std.draw.rect(0, width - 7, 4, 3, 52)

    std.draw.color(std.color.black or {r=0,g=0,b=0})
    for i = 1, 3 do
        local x = (width / 4) * i
        std.draw.rect(0, x, 5, 2, 50)
    end

    draw_pixel_text(std, 10, 20, "BANANAS")
    draw_pixel_number(std, 130, 20, game.score or 0)

    draw_pixel_text(std, 220, 20, "VENDEDORES")
    draw_pixel_number(std, 400, 20, game.kills or 0)

    draw_pixel_text(std, 580, 20, "VIDINHAS")
    local lives = tonumber(game.lives) or 0
    for i = 1, 3 do
        local heart_x = 700 + (i * 24)
        draw_big_pixel_heart(std, heart_x, 18, lives >= i)
    end
end

local function draw_platform(std, platform)
    std.draw.color(platform.color)
    std.draw.rect(0, platform.x, platform.y, platform.width, platform.height)
    
    std.draw.color(std.color.black)
    std.draw.rect(0, platform.x, platform.y, platform.width, 2)
    
    for i = 0, platform.width - 20, 20 do
        std.draw.rect(0, platform.x + i, platform.y + 5, 2, platform.height - 10)
    end
end

local function draw(std, game)
    std.draw.clear(std.color.skyblue)
    
    std.draw.color(std.color.white)
    for i = 1, 5 do
        local cloud_x = ((std.milis / (1000 + i * 500)) % 1) * game.width
        std.draw.rect(0, cloud_x, 50 + i * 30, 60, 20)
    end
    
    for _, platform in ipairs(game.platforms) do
        draw_platform(std, platform)
    end
    
    local p = game.player
    local is_moving = p.speed_x ~= 0
    local is_jumping = p.jumping
    local facing_right = p.facing_right
    local animation_offset = p.animation_timer > 5 and 2 or 0
    
    std.draw.color(std.color.blue)
    if is_moving and not is_jumping then
        std.draw.rect(0, p.x + (facing_right and 5 or 15), p.y + 30 + animation_offset, 10, 10)
        std.draw.rect(0, p.x + (facing_right and 25 or 35), p.y + 30 - animation_offset, 10, 10)
    else
        std.draw.rect(0, p.x + (facing_right and 5 or 15), p.y + 30, 10, 10)
        std.draw.rect(0, p.x + (facing_right and 25 or 35), p.y + 30, 10, 10)
    end
    
    std.draw.color(std.color.yellow)
    std.draw.rect(0, p.x + 10, p.y + 10, 30, 20)
    std.draw.rect(0, p.x, p.y + 10, 10, 10)
    std.draw.rect(0, p.x + 40, p.y + 10, 10, 10)
    
    std.draw.color(std.color.brown)
    if is_jumping then
        std.draw.rect(0, p.x + 15, p.y - animation_offset, 20, 10)
    else
        std.draw.rect(0, p.x + 15, p.y, 20, 10)
    end
    
    draw_cs_logo(std, p.x + 15, p.y + 15)
    
    if is_moving then
        std.draw.color(std.color.brown)
        local tail_x = p.x + (facing_right and -5 or 35)
        local tail_y = p.y + 15 + (animation_offset * 0.5)
        std.draw.rect(0, tail_x, tail_y, 10, 10)
    end
    
    if game.player.has_double_jumped then
        std.draw.color(std.color.white)
        for i = 1, 3 do
            std.draw.rect(0, p.x + 15 + i * 5, p.y + 40 + animation_offset * 2, 3, 3)
        end
    end

    draw_hud(std, game)
        
    for _, enemy in ipairs(game.enemies) do
        draw_enemy(std, game, enemy)
        if enemy.show_speech then
            draw_speech_bubble(std, enemy.x, enemy.y, enemy.speech)
        end
    end
    
    for _, banana in ipairs(game.bananas) do
        draw_banana(std, banana.x, banana.y)
        if std.milis % 1000 < 500 then
            std.draw.color(std.color.white)
            std.draw.rect(0, banana.x + 10, banana.y + 5, 2, 2)
        end
    end
    
    for _, bullet in ipairs(game.bullets) do
        if bullet.damage and bullet.damage > 1 then
            std.draw.color(std.color.orange)
            std.draw.rect(0, bullet.x - 5, bullet.y, 15, 10)
            std.draw.color(std.color.red)
            std.draw.rect(0, bullet.x, bullet.y, 10, 10)
        else
            std.draw.color(bullet.color or std.color.orange)
            std.draw.rect(0, bullet.x, bullet.y, 10, 10)
        end
    end

    
    if game.state == 2 then
        std.draw.color(std.color.black)
        std.draw.rect(0, 0, 0, game.width, game.height, 0.7)
        
        std.text.font_size(40)
        local text = "SE FUDEU, ARRASTA P CIMA P CONTINUAR"
        local width = std.text.mensure(text)
        
        std.draw.color(std.color.red)
        std.text.print(game.width/2 - width/2 + 2, game.height/2 + 2, text)
        
        std.draw.color(std.color.yellow)
        std.text.print(game.width/2 - width/2, game.height/2, text)
        
        std.text.font_size(30)
        local score_text = "Bananas comidas: " .. game.score
        local score_width = std.text.mensure(score_text)
        std.text.print(game.width/2 - score_width/2, game.height/2 + 50, score_text)
    end
end

local function loop(std, game)
    if not game then return end
    
    if game.state == 1 then
        handle_player_movement(std, game)
        
        if game.banana_time > game.BANANA_SPAWN_RATE then
            spawn_banana(std, game)
        end
        
        if game.enemy_time > game.ENEMY_SPAWN_RATE then
            spawn_enemy(std, game)
        end
        
        update_objects(std, game)
        
        game.banana_time = game.banana_time + std.delta
        game.enemy_time = game.enemy_time + std.delta
        
    elseif game.state == 2 and std.key.axis.y == -1 then
        std.app.reset()
    end
end


local function exit(std, game)
    game.bananas = nil
    game.enemies = nil
    game.bullets = nil
    game.platforms = nil
end

local P = {
    meta = {
        title = "Monkey Runner",
        author = "Assistant",
        description = "A platformer game with a monkey collecting bananas and defeating enemies",
        version = "1.0.0"
    },
    config = {
        require = "math math.random" 
    },
    callbacks = {
        init = init,
        loop = loop,
        draw = draw,
        exit = exit
    }
}

return P