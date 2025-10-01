CREATE OR REPLACE PACKAGE BODY find_words_pkg AS

PROCEDURE register_player(p_nick VARCHAR2, p_password VARCHAR2) IS
    v_count NUMBER;
BEGIN
    IF p_nick IS NULL OR TRIM(p_nick) = '' THEN
        RAISE_APPLICATION_ERROR(-20017, 'Никнейм не может быть пустым или состоять только из пробелов!');
        RETURN;
    END IF;
    IF INSTR(p_nick, ' ') > 0 THEN
        RAISE_APPLICATION_ERROR(-20018, 'Никнейм не должен содержать пробелы!');
        RETURN;
    END IF;
    IF LENGTH(p_nick) NOT BETWEEN 1 AND 20 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Никнейм должен быть от 1 до 20 символов');
        RETURN;
    END IF;
    IF NOT REGEXP_LIKE(p_nick, '^[a-zA-Zа-яА-Я0-9_]+$') THEN
        RAISE_APPLICATION_ERROR(-20020, 'Никнейм может содержать только буквы (включая русские), цифры и подчеркивание!');
        RETURN;
    END IF;
    IF p_password IS NULL OR LENGTH(TRIM(p_password)) < 8 THEN
        RAISE_APPLICATION_ERROR(-20008, 'Пароль должен быть не менее 8 символов!');
        RETURN;
    END IF;
    IF LENGTHB(p_password) > 30 THEN
        RAISE_APPLICATION_ERROR(-20021, 'Пароль не должен превышать 30 символов!');
        RETURN;
    END IF;
    IF INSTR(p_password, ' ') > 0 THEN
        RAISE_APPLICATION_ERROR(-20019, 'Пароль не должен содержать пробелы!');
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_count FROM players WHERE nickname = p_nick;
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 'Никнейм "' || p_nick || '" уже зарегистрирован. Выберите другой никнейм.');
        RETURN;
    END IF;

    INSERT INTO players (nickname, password_hash) VALUES (p_nick, p_password);
    INSERT INTO player_results (nickname) VALUES (p_nick);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Пользователь "' || p_nick || '" успешно зарегистрирован.');
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END register_player;

PROCEDURE login_player(p_nick VARCHAR2, p_password VARCHAR2) IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM players
    WHERE nickname = p_nick AND password_hash = p_password;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20030, 'Неверный ник или пароль!');
    END IF;

    DBMS_OUTPUT.PUT_LINE('Успешный вход!');
END login_player;

PROCEDURE start_game(p_theme IN VARCHAR2, p_word_count IN NUMBER DEFAULT 5) AS
   max_word_length  INT := 0;
   field_size       INT;
   direction        VARCHAR2(10);
   word             VARCHAR2(50 CHAR);
   rus_alphabet     VARCHAR2(33 CHAR) := 'абвгґдежзийклмнопрстуфхцчшщыэюя';
   start_row        INT;
   start_col        INT;
   can_place_flag   BOOLEAN;
   existing_letter  VARCHAR2(2 CHAR);
   v_theme_id       NUMBER;
   TYPE word_table IS TABLE OF VARCHAR2(50 CHAR);
   selected_words   word_table;
   placed_words     word_table := word_table();
BEGIN
  BEGIN
        SELECT theme_id INTO v_theme_id 
        FROM themes 
        WHERE LOWER(theme_name) = LOWER(p_theme);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Ошибка: тема "' || p_theme || '" не найдена!');
            DBMS_OUTPUT.PUT_LINE('Доступные темы:');
            FOR theme_rec IN (SELECT theme_name FROM themes ORDER BY 1) LOOP
                DBMS_OUTPUT.PUT_LINE('- ' || theme_rec.theme_name);
            END LOOP;
            ROLLBACK;
            RETURN;
    END;

    DELETE FROM game_field;
    DELETE FROM current_game_words;
    COMMIT;

    SELECT word BULK COLLECT INTO selected_words
    FROM (
        SELECT LOWER(word) AS word 
        FROM words 
        WHERE theme_id = v_theme_id
        ORDER BY DBMS_RANDOM.VALUE
    )
    WHERE ROWNUM <= p_word_count;

    IF selected_words.COUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка: нет слов для выбранной темы!');
        RETURN;
    END IF;

    FOR i IN 1..selected_words.COUNT LOOP
        max_word_length := GREATEST(max_word_length, LENGTH(selected_words(i)));
    END LOOP;
    field_size := GREATEST(max_word_length + 1, selected_words.COUNT); -- Изменено: поле зависит от количества слов

    FOR r IN 1..field_size LOOP
        FOR c IN 1..field_size LOOP
            INSERT INTO game_field (row_num, col_num, letter) VALUES (r, c, NULL);
        END LOOP;
    END LOOP;
    COMMIT;

    FOR i IN 1..selected_words.COUNT LOOP
        word := selected_words(i);
        can_place_flag := FALSE;

        FOR attempt IN 1..1000 LOOP
            start_row := FLOOR(DBMS_RANDOM.VALUE(1, field_size + 1));
            start_col := FLOOR(DBMS_RANDOM.VALUE(1, field_size + 1));
            direction := CASE WHEN DBMS_RANDOM.VALUE < 0.5 THEN 'H' ELSE 'V' END;

            IF direction = 'H' AND start_col + LENGTH(word) - 1 <= field_size THEN
                can_place_flag := TRUE;
                FOR idx IN 0..LENGTH(word)-1 LOOP
                    BEGIN
                        SELECT letter INTO existing_letter
                        FROM game_field
                        WHERE row_num = start_row AND col_num = start_col + idx;

                        IF existing_letter IS NOT NULL AND existing_letter != SUBSTR(word, idx + 1, 1) THEN
                            can_place_flag := FALSE;
                            EXIT;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            can_place_flag := FALSE;
                            EXIT;
                    END;
                END LOOP;

                IF can_place_flag THEN
                    FOR idx IN 1..LENGTH(word) LOOP
                        UPDATE game_field
                        SET letter = SUBSTR(word, idx, 1)
                        WHERE row_num = start_row AND col_num = start_col + idx - 1;
                    END LOOP;
                    placed_words.EXTEND;
                    placed_words(placed_words.LAST) := word;
                    EXIT;
                END IF;

            ELSIF direction = 'V' AND start_row + LENGTH(word) - 1 <= field_size THEN
                can_place_flag := TRUE;
                FOR idx IN 0..LENGTH(word)-1 LOOP
                    BEGIN
                        SELECT letter INTO existing_letter
                        FROM game_field
                        WHERE row_num = start_row + idx AND col_num = start_col;

                        IF existing_letter IS NOT NULL AND existing_letter != SUBSTR(word, idx + 1, 1) THEN
                            can_place_flag := FALSE;
                            EXIT;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            can_place_flag := FALSE;
                            EXIT;
                    END;
                END LOOP;

                IF can_place_flag THEN
                    FOR idx IN 1..LENGTH(word) LOOP
                        UPDATE game_field
                        SET letter = SUBSTR(word, idx, 1)
                        WHERE row_num = start_row + idx - 1 AND col_num = start_col;
                    END LOOP;
                    placed_words.EXTEND;
                    placed_words(placed_words.LAST) := word;
                    EXIT;
                END IF;
            END IF;

            IF attempt = 1000 THEN
                DBMS_OUTPUT.PUT_LINE('Не удалось разместить слово: ' || word);
            END IF;
        END LOOP;
    END LOOP;
    COMMIT;

    IF placed_words.COUNT > 0 THEN
        FORALL i IN 1..placed_words.COUNT
            INSERT INTO current_game_words(word, theme_id) 
            VALUES (placed_words(i), v_theme_id);
        COMMIT;
    END IF;

    FOR r IN 1..field_size LOOP
        FOR c IN 1..field_size LOOP
            UPDATE game_field
            SET letter = SUBSTR(
                rus_alphabet,
                FLOOR(DBMS_RANDOM.VALUE(1, LENGTH(rus_alphabet) + 1)),
                1
            )
            WHERE letter IS NULL
            AND row_num = r
            AND col_num = c;
        END LOOP;
    END LOOP;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Игровое поле для темы "' || UPPER(p_theme) || '":');
    FOR r IN 1..field_size LOOP
        DECLARE
            output_line VARCHAR2(4000);
        BEGIN
            SELECT LISTAGG(NVL(letter, '*'), ' ') WITHIN GROUP (ORDER BY col_num)
            INTO output_line
            FROM game_field
            WHERE row_num = r;
            DBMS_OUTPUT.PUT_LINE(output_line);
        END;
    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка: ' || SQLERRM);
        ROLLBACK;
END start_game;

PROCEDURE find_word(p_word IN VARCHAR2) AS
    v_word_lower      VARCHAR2(50) := LOWER(p_word);
    v_word_len        NUMBER := LENGTH(p_word);
    v_field_size      NUMBER;
    v_found           BOOLEAN := FALSE;
    v_current_theme   NUMBER;
BEGIN
    BEGIN
        SELECT theme_id INTO v_current_theme
        FROM current_game_words
        FETCH FIRST 1 ROWS ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Игра не инициализирована!');
            RETURN;
    END;

    DECLARE
        v_exists        NUMBER := 0;
        v_already_found NUMBER := 0;
    BEGIN
        SELECT COUNT(*), SUM(CASE WHEN found = 'Y' THEN 1 ELSE 0 END)
        INTO v_exists, v_already_found
        FROM current_game_words
        WHERE LOWER(word) = v_word_lower;  -- Изменено: регистронезависимое сравнение

        IF v_exists = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Слово "' || p_word || '" не входит в текущую игру!');
            RETURN;
        ELSIF v_already_found > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Слово "' || p_word || '" уже было найдено!');
            RETURN;
        END IF;
    END;

    SELECT MAX(row_num) INTO v_field_size FROM game_field;

    FOR r IN 1..v_field_size LOOP
        FOR c IN 1..(v_field_size - v_word_len + 1) LOOP
            DECLARE
                current_word VARCHAR2(50);
            BEGIN
                SELECT LISTAGG(letter, '') WITHIN GROUP (ORDER BY col_num)
                INTO current_word
                FROM game_field
                WHERE row_num = r AND col_num BETWEEN c AND c + v_word_len - 1;

                IF LOWER(current_word) = v_word_lower THEN
                    FOR i IN 1..v_word_len LOOP
                        UPDATE game_field
                        SET letter = UPPER(SUBSTR(current_word, i, 1))
                        WHERE row_num = r AND col_num = c + i - 1;
                    END LOOP;
                    v_found := TRUE;
                END IF;
            END;
        END LOOP;
    END LOOP;

    FOR c IN 1..v_field_size LOOP
        FOR r IN 1..(v_field_size - v_word_len + 1) LOOP
            DECLARE
                current_word VARCHAR2(50);
            BEGIN
                SELECT LISTAGG(letter, '') WITHIN GROUP (ORDER BY row_num)
                INTO current_word
                FROM game_field
                WHERE col_num = c AND row_num BETWEEN r AND r + v_word_len - 1;

                IF LOWER(current_word) = v_word_lower THEN
                    FOR i IN 1..v_word_len LOOP
                        UPDATE game_field
                        SET letter = UPPER(SUBSTR(current_word, i, 1))
                        WHERE row_num = r + i - 1 AND col_num = c;
                    END LOOP;
                    v_found := TRUE;
                END IF;
            END;
        END LOOP;
    END LOOP;

    IF v_found THEN
        UPDATE current_game_words
        SET found = 'Y'
        WHERE LOWER(word) = v_word_lower;  -- Изменено: регистронезависимое сравнение

        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Слово "' || p_word || '" успешно найдено!');

        DECLARE
            v_found_count NUMBER;
            v_total_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_found_count FROM current_game_words WHERE found = 'Y';
            SELECT COUNT(*) INTO v_total_count FROM current_game_words;

            DBMS_OUTPUT.PUT_LINE('Текущее поле:');
            FOR r IN 1..v_field_size LOOP
                DECLARE
                    v_row VARCHAR2(100);
                BEGIN
                    SELECT LISTAGG(letter, ' ') WITHIN GROUP (ORDER BY col_num)
                    INTO v_row
                    FROM game_field
                    WHERE row_num = r;
                    
                    DBMS_OUTPUT.PUT_LINE(v_row);
                END;
            END LOOP;
        END;

        check_game_complete;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Слово "' || p_word || '" не найдено на поле!');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка при обработке слова: ' || SQLERRM);
        ROLLBACK;
END find_word;

PROCEDURE check_game_complete AS
    v_total_words NUMBER;
    v_found_words NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_total_words 
    FROM current_game_words;

    SELECT COUNT(*) INTO v_found_words 
    FROM current_game_words 
    WHERE found = 'Y';

    IF v_total_words = v_found_words THEN
        DBMS_OUTPUT.PUT_LINE('Поздравляем! Все слова найдены!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Найдено ' || v_found_words || ' из ' || v_total_words);
    END IF;
END check_game_complete;

PROCEDURE print_game_field AS
    v_field_size NUMBER;
BEGIN
    SELECT MAX(row_num) INTO v_field_size FROM game_field;
    
    IF v_field_size IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('Игровое поле не создано!');
        RETURN;
    END IF;

    FOR r IN 1..v_field_size LOOP
        DECLARE
            output_line VARCHAR2(4000);
        BEGIN
            SELECT LISTAGG(NVL(letter, '*'), ' ') WITHIN GROUP (ORDER BY col_num)
            INTO output_line
            FROM game_field
            WHERE row_num = r;
            
            DBMS_OUTPUT.PUT_LINE(output_line);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('*');
        END;
    END LOOP;
END print_game_field;

PROCEDURE display_game_rules AS
    CURSOR theme_cursor IS
        SELECT theme_name
        FROM themes
        ORDER BY theme_name;
    v_theme_name themes.theme_name%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Правила игры "Поиск слов":');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('- В начале игры выбирается 1 из 5 доступных тем');
    DBMS_OUTPUT.PUT_LINE('  Доступные темы:');
    -- Вывод списка тем
    OPEN theme_cursor;
    LOOP
        FETCH theme_cursor INTO v_theme_name;
        EXIT WHEN theme_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('    - ' || v_theme_name);
    END LOOP;
    CLOSE theme_cursor;
    DBMS_OUTPUT.PUT_LINE('- Для выбранной темы случайно отбирается 5 слов');
    DBMS_OUTPUT.PUT_LINE('  Размер поля рассчитывается как:');
    DBMS_OUTPUT.PUT_LINE('  (длина самого длинного слова + 1), но не менее 6x6');
    DBMS_OUTPUT.PUT_LINE('- Слова размещаются горизонтально или вертикально');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Как играть:');
    DBMS_OUTPUT.PUT_LINE('- Используйте процедуру generate_game_field("тема")');
    DBMS_OUTPUT.PUT_LINE('  для старта новой игры');
    DBMS_OUTPUT.PUT_LINE('- Вводите найденные слова через check_and_highlight_word');
    DBMS_OUTPUT.PUT_LINE('- Поиск слов осуществляется по направлению:');
    DBMS_OUTPUT.PUT_LINE('  слева-направо (горизонтально)');
    DBMS_OUTPUT.PUT_LINE('  сверху-вниз (вертикально)');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Пример запуска:');
    DBMS_OUTPUT.PUT_LINE('BEGIN');
    DBMS_OUTPUT.PUT_LINE('  display_game_rules();');
    DBMS_OUTPUT.PUT_LINE('  generate_game_field(''животные'');');
    DBMS_OUTPUT.PUT_LINE('  check_and_highlight_word(''тигр'');');
    DBMS_OUTPUT.PUT_LINE('END;');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------');
EXCEPTION
    WHEN OTHERS THEN
        IF theme_cursor%ISOPEN THEN
            CLOSE theme_cursor;
        END IF;
        RAISE_APPLICATION_ERROR(-20001, 'Ошибка при выводе тем: ' || SQLERRM);
END display_game_rules;

PROCEDURE display_game_words AS
BEGIN
    -- Проверка текущего пользователя
    IF USER != 'KC2104_11' THEN
        RAISE_APPLICATION_ERROR(-20002, 'Нет доступа');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('Слова текущей игры:');
    FOR word_rec IN (SELECT * FROM current_game_words ORDER BY word) LOOP
        DBMS_OUTPUT.PUT_LINE(word_rec.word || ' - ' || 
            CASE WHEN word_rec.found = 'Y' THEN 'Найдено' ELSE 'Не найдено' END);
    END LOOP;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Нет активной игры!');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'Ошибка при выводе слов: ' || SQLERRM);
END display_game_words;

END find_words_pkg;
