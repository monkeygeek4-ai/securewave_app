<?php
// backend/lib/Database.php

class Database {
    private static $instance = null;
    private $conn = null;
    private $config = [];
    
    private function __construct() {
<<<<<<< HEAD
        // Загружаем конфигурацию напрямую из .env
        $this->loadEnvDirect();
        $this->connect();
    }
    
    private function loadEnvDirect() {
        // Загружаем напрямую из .env файла
=======
        // Загружаем конфигурацию из .env файла
        $this->loadConfig();
        $this->connect();
    }
    
    private function loadConfig() {
        // Сначала пробуем загрузить из config.php если есть
        $configFile = dirname(__DIR__) . '/config/config.php';
        if (file_exists($configFile)) {
            $fullConfig = require $configFile;
            $this->config = $fullConfig['database'];
            
            // Проверяем обязательные параметры
            $this->validateConfig();
            return;
        }
        
        // Если нет config.php, загружаем напрямую из .env
>>>>>>> 6c0a886a6502e429bdd6288c5188b4477e0387e6
        $envFile = dirname(__DIR__) . '/.env';
        if (!file_exists($envFile)) {
            throw new Exception(
                "Configuration error: .env file not found at " . $envFile . "\n" .
                "Please create .env file with database credentials.\n" .
                "Example:\n" .
                "DB_HOST=localhost\n" .
                "DB_PORT=5432\n" .
                "DB_NAME=your_database\n" .
                "DB_USER=your_username\n" .
                "DB_PASSWORD=your_password"
            );
        }
        
        // Читаем .env файл
        $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        
        foreach ($lines as $line) {
            // Пропускаем комментарии
            if (strpos(trim($line), '#') === 0) {
                continue;
            }
            
            // Разбираем строку
            if (strpos($line, '=') !== false) {
                list($key, $value) = explode('=', $line, 2);
                $key = trim($key);
                $value = trim($value);
                
                // Убираем кавычки если есть
                if ((substr($value, 0, 1) === '"' && substr($value, -1) === '"') ||
                    (substr($value, 0, 1) === "'" && substr($value, -1) === "'")) {
                    $value = substr($value, 1, -1);
                }
                
                $_ENV[$key] = $value;
            }
        }
        
        // Формируем конфигурацию из переменных окружения
        $this->config = [
            'host' => $_ENV['DB_HOST'] ?? null,
            'port' => $_ENV['DB_PORT'] ?? 5432,
            'database' => $_ENV['DB_NAME'] ?? null,
            'username' => $_ENV['DB_USER'] ?? null,
            'password' => $_ENV['DB_PASSWORD'] ?? null
        ];
        
        // Проверяем обязательные параметры
        $this->validateConfig();
    }
    
    /**
     * Проверка наличия всех обязательных параметров конфигурации
     */
    private function validateConfig() {
        $required = ['host', 'database', 'username', 'password'];
        $missing = [];
        
        foreach ($required as $param) {
            if (empty($this->config[$param])) {
<<<<<<< HEAD
                $missing[] = 'DB_' . strtoupper($param);
=======
                $missing[] = strtoupper($param);
>>>>>>> 6c0a886a6502e429bdd6288c5188b4477e0387e6
            }
        }
        
        if (!empty($missing)) {
            throw new Exception(
                "Database configuration error: Missing required parameters: " . 
                implode(', ', $missing) . "\n" .
<<<<<<< HEAD
                "Please check your .env file."
=======
                "Please check your .env file and ensure these variables are set:\n" .
                implode("\n", array_map(function($p) { 
                    return "DB_" . $p . "=your_value"; 
                }, $missing))
>>>>>>> 6c0a886a6502e429bdd6288c5188b4477e0387e6
            );
        }
    }
    
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    private function connect() {
        try {
            // Формируем DSN для PostgreSQL
            $dsn = sprintf(
                "pgsql:host=%s;port=%s;dbname=%s",
                $this->config['host'],
                $this->config['port'] ?? 5432,
                $this->config['database']
            );
            
            $this->conn = new PDO(
                $dsn,
                $this->config['username'],
                $this->config['password'],
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false
                ]
            );
            
            // Устанавливаем кодировку
            $this->conn->exec("SET NAMES 'utf8'");
            $this->conn->exec("SET CLIENT_ENCODING TO 'utf8'");
            
        } catch (PDOException $e) {
            error_log("Database connection failed: " . $e->getMessage());
<<<<<<< HEAD
=======
            error_log("DSN: " . $dsn);
            error_log("Username: " . $this->config['username']);
            // НЕ логируем пароль в целях безопасности!
>>>>>>> 6c0a886a6502e429bdd6288c5188b4477e0387e6
            throw new Exception(
                "Database connection failed. Please check your database credentials in .env file.\n" .
                "Error: " . $e->getMessage()
            );
        }
    }
    
    public function getConnection() {
        if (!$this->conn) {
            $this->connect();
        }
        return $this->conn;
    }
    
    public function execute($sql, $params = []) {
        try {
            $stmt = $this->conn->prepare($sql);
            $stmt->execute($params);
            return $stmt;
        } catch (PDOException $e) {
            error_log("Query failed: " . $e->getMessage() . " SQL: " . $sql);
            throw new Exception("Query failed: " . $e->getMessage());
        }
    }
    
    public function fetchAll($sql, $params = []) {
        $stmt = $this->execute($sql, $params);
        return $stmt->fetchAll();
    }
    
    public function fetchOne($sql, $params = []) {
        $stmt = $this->execute($sql, $params);
        return $stmt->fetch();
    }
    
    public function fetchColumn($sql, $params = []) {
        $stmt = $this->execute($sql, $params);
        return $stmt->fetchColumn();
    }
    
    public function insert($sql, $params = []) {
        // Для PostgreSQL с RETURNING
        if (stripos($sql, 'RETURNING') !== false) {
            $stmt = $this->execute($sql, $params);
            return $stmt->fetchColumn();
        }
        
        // Обычный INSERT
        $this->execute($sql, $params);
        
<<<<<<< HEAD
=======
        // Для PostgreSQL нужно указывать последовательность
        // Попробуем получить последний ID
        try {
            // Пытаемся получить последний ID из последовательности messages
            $lastId = $this->conn->lastInsertId('messages_id_seq');
            if ($lastId) {
                return $lastId;
            }
        } catch (Exception $e) {
            // Если не получилось, пробуем другой способ
        }
        
>>>>>>> 6c0a886a6502e429bdd6288c5188b4477e0387e6
        // Альтернативный способ для PostgreSQL
        try {
            $result = $this->fetchOne("SELECT lastval()");
            return $result ? $result['lastval'] : null;
        } catch (Exception $e) {
            return null;
        }
    }
    
<<<<<<< HEAD
    public function lastInsertId($sequence = null) {
        if ($sequence) {
            return $this->conn->lastInsertId($sequence);
        }
        
=======
    // Метод для получения ID последней вставленной записи
    public function lastInsertId($sequence = null) {
        if ($sequence) {
            // Для PostgreSQL с указанием последовательности
            return $this->conn->lastInsertId($sequence);
        }
        
        // Попробуем получить через lastval()
>>>>>>> 6c0a886a6502e429bdd6288c5188b4477e0387e6
        try {
            $result = $this->fetchOne("SELECT lastval()");
            return $result ? $result['lastval'] : null;
        } catch (Exception $e) {
<<<<<<< HEAD
            return null;
        }
    }
=======
            return $this->conn->lastInsertId();
        }
    }
    
    public function beginTransaction() {
        return $this->conn->beginTransaction();
    }
    
    public function commit() {
        return $this->conn->commit();
    }
    
    public function rollback() {
        return $this->conn->rollBack();
    }
    
    public function inTransaction() {
        return $this->conn->inTransaction();
    }
    
    // Вспомогательный метод для отладки
    public function getLastError() {
        return $this->conn->errorInfo();
    }
    
    // Метод для проверки соединения
    public function isConnected() {
        try {
            if (!$this->conn) {
                return false;
            }
            $this->conn->query('SELECT 1');
            return true;
        } catch (PDOException $e) {
            return false;
        }
    }
    
    // Метод для переподключения
    public function reconnect() {
        $this->conn = null;
        $this->connect();
    }
>>>>>>> 6c0a886a6502e429bdd6288c5188b4477e0387e6
}