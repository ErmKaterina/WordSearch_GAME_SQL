
CREATE OR REPLACE PACKAGE find_words_pkg AS
    PROCEDURE start_game(p_theme IN VARCHAR2, p_word_count IN NUMBER DEFAULT 5);
    PROCEDURE find_word(p_word IN VARCHAR2);
    PROCEDURE check_game_complete;
    PROCEDURE print_game_field;
    PROCEDURE display_game_rules;
    PROCEDURE display_game_words;
    PROCEDURE register_player(p_nick VARCHAR2, p_password VARCHAR2);
    PROCEDURE login_player(p_nick VARCHAR2, p_password VARCHAR2);
END find_words_pkg;
