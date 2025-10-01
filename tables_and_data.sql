
CREATE TABLE themes (
    theme_id NUMBER PRIMARY KEY,
    theme_name VARCHAR2(50 CHAR) UNIQUE NOT NULL
);
CREATE TABLE words (
    word_id NUMBER PRIMARY KEY,
    word VARCHAR2(50 CHAR) NOT NULL,
    theme_id NUMBER NOT NULL,
    CONSTRAINT fk_theme FOREIGN KEY (theme_id) REFERENCES themes(theme_id)
);

CREATE TABLE game_field (
    row_num INT,
    col_num INT,
    letter VARCHAR2(2 CHAR)
);
CREATE TABLE current_game_words (
    word VARCHAR2(50 CHAR) PRIMARY KEY,
    theme_id NUMBER,
    found CHAR(1) DEFAULT 'N' CHECK (found IN ('Y', 'N'))
);

CREATE TABLE players (
    nickname VARCHAR2(100) PRIMARY KEY,
    password_hash VARCHAR2(100) NOT NULL
);

-- Таблица результатов
CREATE TABLE player_results (
    nickname VARCHAR2(100) PRIMARY KEY,
    best_time NUMBER DEFAULT NULL, -- в секундах
    games_played NUMBER DEFAULT 0,
    games_won NUMBER DEFAULT 0
);


INSERT INTO themes (theme_id, theme_name) VALUES (1, 'Животные');
INSERT INTO themes (theme_id, theme_name) VALUES (2, 'Деревья');
INSERT INTO themes (theme_id, theme_name) VALUES (3, 'Овощи');
INSERT INTO themes (theme_id, theme_name) VALUES (4, 'Напитки');
INSERT INTO themes (theme_id, theme_name) VALUES (5, 'Фрукты');
INSERT INTO words (word_id, word, theme_id) VALUES (1, 'Кот', 1);
INSERT INTO words (word_id, word, theme_id) VALUES (2, 'Пёс', 1);
INSERT INTO words (word_id, word, theme_id) VALUES (3, 'Лиса', 1);
INSERT INTO words (word_id, word, theme_id) VALUES (4, 'Волк', 1);
INSERT INTO words (word_id, word, theme_id) VALUES (5, 'Заяц', 1);
INSERT INTO words (word_id, word, theme_id) VALUES (6, 'Ёж', 1);
INSERT INTO words (word_id, word, theme_id) VALUES (7, 'Белка', 1);
INSERT INTO words (word_id, word, theme_id) VALUES (8, 'Мышь', 1);
INSERT INTO words (word_id, word, theme_id) VALUES (9, 'Сова', 1);
INSERT INTO words (word_id, word, theme_id) VALUES (10, 'Крот', 1);

INSERT INTO words (word_id, word, theme_id) VALUES (11, 'Сосна', 2);
INSERT INTO words (word_id, word, theme_id) VALUES (12, 'Ель', 2);
INSERT INTO words (word_id, word, theme_id) VALUES (13, 'Дуб', 2);
INSERT INTO words (word_id, word, theme_id) VALUES (14, 'Клён', 2);
INSERT INTO words (word_id, word, theme_id) VALUES (15, 'Липа', 2);
INSERT INTO words (word_id, word, theme_id) VALUES (16, 'Ясень', 2);
INSERT INTO words (word_id, word, theme_id) VALUES (17, 'Кедр', 2);
INSERT INTO words (word_id, word, theme_id) VALUES (18, 'Ива', 2);
INSERT INTO words (word_id, word, theme_id) VALUES (19, 'Осина', 2);
INSERT INTO words (word_id, word, theme_id) VALUES (20, 'Тис', 2);

INSERT INTO words (word_id, word, theme_id) VALUES (21, 'Лук', 3);
INSERT INTO words (word_id, word, theme_id) VALUES (22, 'Чеснок', 3);
INSERT INTO words (word_id, word, theme_id) VALUES (23, 'Редис', 3);
INSERT INTO words (word_id, word, theme_id) VALUES (24, 'Тыква', 3);
INSERT INTO words (word_id, word, theme_id) VALUES (25, 'Горох', 3);
INSERT INTO words (word_id, word, theme_id) VALUES (26, 'Фасоль', 3);
INSERT INTO words (word_id, word, theme_id) VALUES (27, 'Кабак', 3);
INSERT INTO words (word_id, word, theme_id) VALUES (28, 'Патиссон', 3);
INSERT INTO words (word_id, word, theme_id) VALUES (29, 'Репа', 3);
INSERT INTO words (word_id, word, theme_id) VALUES (30, 'Брюква', 3);

INSERT INTO words (word_id, word, theme_id) VALUES (31, 'Чай', 4);
INSERT INTO words (word_id, word, theme_id) VALUES (32, 'Кофе', 4);
INSERT INTO words (word_id, word, theme_id) VALUES (33, 'Сок', 4);
INSERT INTO words (word_id, word, theme_id) VALUES (34, 'Вода', 4);
INSERT INTO words (word_id, word, theme_id) VALUES (35, 'Квас', 4);
INSERT INTO words (word_id, word, theme_id) VALUES (36, 'Пиво', 4);
INSERT INTO words (word_id, word, theme_id) VALUES (37, 'Вино', 4);
INSERT INTO words (word_id, word, theme_id) VALUES (38, 'Морс', 4);
INSERT INTO words (word_id, word, theme_id) VALUES (39, 'Сидр', 4);
INSERT INTO words (word_id, word, theme_id) VALUES (40, 'Эль', 4);

INSERT INTO words (word_id, word, theme_id) VALUES (41, 'Слива', 5);
INSERT INTO words (word_id, word, theme_id) VALUES (42, 'Груша', 5);
INSERT INTO words (word_id, word, theme_id) VALUES (43, 'Лимон', 5);
INSERT INTO words (word_id, word, theme_id) VALUES (44, 'Киви', 5);
INSERT INTO words (word_id, word, theme_id) VALUES (45, 'Вишня', 5);
INSERT INTO words (word_id, word, theme_id) VALUES (46, 'Манго', 5);
INSERT INTO words (word_id, word, theme_id) VALUES (47, 'Айва', 5);
INSERT INTO words (word_id, word, theme_id) VALUES (48, 'Гранат', 5);
INSERT INTO words (word_id, word, theme_id) VALUES (49, 'Хурма', 5);
INSERT INTO words (word_id, word, theme_id) VALUES (50, 'Банан', 5);