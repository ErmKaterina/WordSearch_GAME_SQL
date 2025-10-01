import oracledb
import tkinter as tk
from tkinter import messagebox, Toplevel
from tkinter import ttk  # Для Treeview

# Класс для работы с Oracle
class OracleGame:
    def __init__(self, user, password, dsn):
        self.user = user
        self.password = password
        self.dsn = dsn

    def get_connection(self):
        return oracledb.connect(user=self.user, password=self.password, dsn=self.dsn)

    def start_game(self, theme, word_count=5):
        conn = self.get_connection()
        cursor = conn.cursor()
        try:
            cursor.callproc('find_words_pkg.start_game', [theme, word_count])
            conn.commit()
            print(f"Игра запущена с {word_count} словами.")
        except Exception as e:
            print("Ошибка при запуске игры:", e)
        finally:
            cursor.close()
            conn.close()

    def find_word(self, word):
        conn = self.get_connection()
        cursor = conn.cursor()
        try:
            cursor.callproc('find_words_pkg.find_word', [word])
            conn.commit()
        except Exception as e:
            print("Ошибка при поиске слова:", e)
        finally:
            cursor.close()
            conn.close()

    def get_field(self):
        conn = self.get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("""
                SELECT row_num, col_num, letter
                FROM game_field
                ORDER BY row_num, col_num
            """)
            rows = cursor.fetchall()
            field = {}
            for r, c, letter in rows:
                field[(r, c)] = letter
            return field
        except Exception as e:
            print("Ошибка получения поля:", e)
            return {}
        finally:
            cursor.close()
            conn.close()

    def get_game_status(self):
        conn = self.get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("""
                SELECT COUNT(*) FROM current_game_words
            """)
            total = cursor.fetchone()[0]
            print(f"[DEBUG] Total words: {total}")

            cursor.execute("""
                SELECT COUNT(*) FROM current_game_words WHERE found = 'Y'
            """)
            found = cursor.fetchone()[0]
            print(f"[DEBUG] Found words: {found}")

            return found, total
        except Exception as e:
            print("Ошибка получения статуса игры:", e)
            return 0, 0
        finally:
            cursor.close()
            conn.close()

    def register_player(self, nick, password):
        conn = self.get_connection()
        cursor = conn.cursor()
        try:
            cursor.callproc('find_words_pkg.register_player', [nick, password])
            conn.commit()
            messagebox.showinfo("Успех", f"Игрок '{nick}' успешно зарегистрирован!")
            return True
        except Exception as e:
            messagebox.showerror("Ошибка", str(e))
            return False
        finally:
            cursor.close()
            conn.close()

    def login_player(self, nick, password):
        conn = self.get_connection()
        cursor = conn.cursor()
        try:
            cursor.callproc('find_words_pkg.login_player', [nick, password])
            conn.commit()
            return True
        except Exception as e:
            messagebox.showerror("Ошибка", str(e))
            return False
        finally:
            cursor.close()
            conn.close()

    def save_best_time(self, nick, total_time):
        conn = self.get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("""
                UPDATE player_results
                SET best_time = CASE WHEN best_time IS NULL OR best_time > :time THEN :time ELSE best_time END,
                    games_won = games_won + 1,
                    games_played = games_played + 1
                WHERE nickname = :nick
            """, {"time": total_time, "nick": nick})
            conn.commit()
            print(f"Лучшее время игрока '{nick}' обновлено: {total_time} секунд.")
        except Exception as e:
            print("Ошибка сохранения результата:", e)
        finally:
            cursor.close()
            conn.close()

    def get_rating(self):
        conn = self.get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("""
                SELECT nickname, best_time, games_won, games_played
                FROM player_results
                WHERE best_time IS NOT NULL
                ORDER BY best_time ASC
            """)
            rows = cursor.fetchall()
            return rows
        except Exception as e:
            print("Ошибка получения рейтинга:", e)
            return []
        finally:
            cursor.close()
            conn.close()

# Класс GUI
class WordSearchGUI:
    def __init__(self, oracle_game):
        self.oracle_game = oracle_game
        self.root = tk.Tk()
        self.root.title("Игра 'Найди слово'")
        self.root.geometry("600x500")

        # Переменные игры
        self.nick = None
        self.start_time = None
        self.timer_running = False
        self.current_level = 1
        self.max_levels = 3
        self.total_time = 0
        self.in_game = False

        # Показываем главное меню
        self.show_main_menu()

    def show_main_menu(self):
        # Очистка окна
        for widget in self.root.winfo_children():
            widget.destroy()

        tk.Label(self.root, text="Игра 'Найди слово'", font=("Arial", 16)).pack(pady=20)

        tk.Button(self.root, text="Зарегистрироваться", command=self.open_register_window).pack(pady=10)
        tk.Button(self.root, text="Войти", command=self.open_login_window).pack(pady=10)
        tk.Button(self.root, text="Рейтинг", command=self.show_rating).pack(pady=10)
        tk.Button(self.root, text="Выход", command=self.root.quit).pack(pady=10)

    def open_register_window(self):
        reg_window = Toplevel(self.root)
        reg_window.title("Регистрация игрока")

        tk.Label(reg_window, text="Никнейм:").pack()
        nick_entry = tk.Entry(reg_window)
        nick_entry.pack()

        tk.Label(reg_window, text="Пароль (не менее 8 символов):").pack()
        pass_entry = tk.Entry(reg_window, show="*")
        pass_entry.pack()

        def submit():
            nick = nick_entry.get().strip()
            password = pass_entry.get()
            if not nick or not password:
                messagebox.showwarning("Ошибка", "Заполните все поля!")
                return
            if self.oracle_game.register_player(nick, password):
                self.nick = nick
                reg_window.destroy()
                self.show_theme_selection()

        tk.Button(reg_window, text="Зарегистрироваться", command=submit).pack(pady=5)

    def open_login_window(self):
        login_window = Toplevel(self.root)
        login_window.title("Вход")

        tk.Label(login_window, text="Никнейм:").pack()
        nick_entry = tk.Entry(login_window)
        nick_entry.pack()

        tk.Label(login_window, text="Пароль:").pack()
        pass_entry = tk.Entry(login_window, show="*")
        pass_entry.pack()

        def submit():
            nick = nick_entry.get().strip()
            password = pass_entry.get()
            if not nick or not password:
                messagebox.showwarning("Ошибка", "Введите ник и пароль!")
                return
            if self.oracle_game.login_player(nick, password):
                self.nick = nick
                login_window.destroy()
                self.show_theme_selection()

        tk.Button(login_window, text="Войти", command=submit).pack(pady=5)

    def show_theme_selection(self):
        # Очистка окна
        for widget in self.root.winfo_children():
            widget.destroy()

        tk.Label(self.root, text="Выберите тему для игры:", font=("Arial", 14)).pack(pady=20)

        self.theme_var = tk.StringVar(value="деревья")
        themes = ["животные", "деревья", "овощи", "напитки", "фрукты"]
        for theme in themes:
            tk.Radiobutton(self.root, text=theme, variable=self.theme_var, value=theme).pack()

        tk.Button(self.root, text="Начать игру", command=self.start_game).pack(pady=20)
        tk.Button(self.root, text="Выйти в меню", command=self.show_main_menu).pack(pady=5)

    def start_game(self):
        self.in_game = True
        # Очистка окна и создание интерфейса игры
        for widget in self.root.winfo_children():
            widget.destroy()

        # Кнопка "Выйти в меню"
        tk.Button(self.root, text="Выйти в меню", command=self.return_to_menu).pack(pady=5)

        # Выбор темы (уже выбрана)
        tk.Label(self.root, text=f"Тема: {self.theme_var.get()}").pack()

        tk.Button(self.root, text="Начать уровень", command=self.start_level).pack(pady=5)

        # Поле ввода слова
        tk.Label(self.root, text="Введите слово:").pack()
        self.word_entry = tk.Entry(self.root)
        self.word_entry.pack()
        tk.Button(self.root, text="Найти слово", command=self.find_word).pack(pady=5)

        # Метка статуса
        self.status_label = tk.Label(self.root, text="Найдено 0 из 0", fg="blue")
        self.status_label.pack()

        # Метка таймера
        self.timer_label = tk.Label(self.root, text="Время: 10:00", fg="red")
        self.timer_label.pack()

        # Игровое поле
        self.field_frame = tk.Frame(self.root)
        self.field_frame.pack()

        self.field_buttons = {}

    def start_level(self):
        theme = self.theme_var.get()
        word_count = 4 + self.current_level  # 5, 6, 7 слов
        self.oracle_game.start_game(theme, word_count)
        self.update_field()
        self.update_status()

        # Сброс таймера
        self.start_time = time.time()
        self.timer_running = True
        self.update_timer()

    def find_word(self):
        word = self.word_entry.get().strip()
        if not word:
            messagebox.showwarning("Внимание", "Введите слово!")
            return
        print(f"[DEBUG] Ищу слово: {word}")
        self.oracle_game.find_word(word)
        self.update_field()
        self.update_status()
        self.word_entry.delete(0, tk.END)

    def update_status(self):
        if self.start_time is None:
            return  # Не обновляем статус, если игра ещё не начата

        found, total = self.oracle_game.get_game_status()
        print(f"[DEBUG] Status: found={found}, total={total}")
        self.status_label.config(text=f"Найдено {found} из {total}")

        if found > 0 and found == total:
            self.timer_running = False
            elapsed = int(time.time() - self.start_time)
            mins, secs = divmod(elapsed, 60)

            # Добавляем время к общему
            self.total_time += elapsed

            # Проверяем, последний ли это уровень
            if self.current_level >= self.max_levels:
                total_mins, total_secs = divmod(self.total_time, 60)
                messagebox.showinfo("Поздравляем!", f"Все уровни пройдены!\nОбщее время: {total_mins:02d}:{total_secs:02d}")
                # Сохраняем лучшее время
                if self.nick:
                    self.oracle_game.save_best_time(self.nick, self.total_time)
                self.return_to_menu()
            else:
                messagebox.showinfo("Поздравляем!", f"Уровень {self.current_level} пройден!\nВремя: {mins:02d}:{secs:02d}\nПереход на уровень {self.current_level + 1}")
                self.current_level += 1
                self.start_level()

    def update_timer(self):
        if not self.timer_running:
            print("[DEBUG] Таймер остановлен")
            return

        elapsed = int(time.time() - self.start_time)
        remaining = 600 - elapsed  # 10 минут = 600 секунд

        if remaining <= 0:
            self.timer_running = False
            messagebox.showinfo("Время вышло!", "Время на игру закончилось.")
            return

        mins, secs = divmod(remaining, 60)
        self.timer_label.config(text=f"Время: {mins:02d}:{secs:02d}")
        print(f"[DEBUG] Осталось: {mins:02d}:{secs:02d}")
        self.root.after(1000, self.update_timer)

    def return_to_menu(self):
        self.in_game = False
        # Останавливаем таймер
        self.timer_running = False
        # Очищаем игровое поле
        for btn in self.field_buttons.values():
            btn.destroy()
        self.field_buttons.clear()
        # Сбрасываем переменные игры
        self.current_level = 1
        self.total_time = 0
        self.start_time = None
        # Разлогиниваем игрока
        self.nick = None
        # Показываем главное меню
        self.show_main_menu()

    def update_field(self):
        field = self.oracle_game.get_field()
        if not field:
            return

        # Очистка старого поля
        for btn in self.field_buttons.values():
            btn.destroy()
        self.field_buttons.clear()

        # Найти размер поля
        rows = sorted(set(r for r, _ in field.keys()))
        cols = sorted(set(c for _, c in field.keys()))

        for r in rows:
            for c in cols:
                letter = field.get((r, c), '?')
                btn = tk.Button(self.field_frame, text=letter, width=4, height=2)
                btn.grid(row=r-1, column=c-1)  # индексация с 0
                self.field_buttons[(r, c)] = btn

    def show_rating(self):
        rating_window = Toplevel(self.root)
        rating_window.title("Рейтинг игроков")
        rating_window.geometry("600x400")

        tk.Label(rating_window, text="Рейтинг игроков", font=("Arial", 16)).pack(pady=10)

        # Создаём таблицу (Treeview)
        tree = ttk.Treeview(rating_window, columns=("Rank", "Nickname", "Time", "Wins"), show="headings")
        tree.heading("Rank", text="Место")
        tree.heading("Nickname", text="Ник")
        tree.heading("Time", text="Лучшее время")
        tree.heading("Wins", text="Побед")

        tree.column("Rank", width=60, anchor="center")
        tree.column("Nickname", width=150, anchor="w")
        tree.column("Time", width=120, anchor="center")
        tree.column("Wins", width=80, anchor="center")

        # Получаем данные рейтинга
        rows = self.oracle_game.get_rating()

        for i, (nick, best_time, won, played) in enumerate(rows, 1):
            mins, secs = divmod(best_time, 60) if best_time else (0, 0)
            time_str = f"{mins:02d}:{secs:02d}"
            tree.insert("", "end", values=(i, nick, time_str, won))

        tree.pack(fill="both", expand=True, padx=10, pady=10)

        # Выделение первых 3 мест (если есть)
        children = tree.get_children()
        for idx in range(min(3, len(children))):
            tree.tag_configure(f"top{idx+1}", background=["#FFD700", "#C0C0C0", "#CD7F32"][idx])  # Золото, Серебро, Бронза
            tree.item(children[idx], tags=(f"top{idx+1}",))

        # Добавим прокрутку (если нужно)
        scrollbar = ttk.Scrollbar(rating_window, orient="vertical", command=tree.yview)
        tree.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side="right", fill="y")

    def run(self):
        self.root.mainloop()

# Запуск приложения
if __name__ == "__main__":
    import time  # Добавляем import time

    # Подключение с твоими данными
    db = OracleGame(
        user="DEVEL333",
        password="DEVEL333",
        dsn="localhost:1521/xe"  # измените, если у вас другой DSN
    )

    app = WordSearchGUI(db)
    app.run()