<?php
require_once __DIR__ . '/../vendor/autoload.php';

use Pushok\AuthProvider;
use Pushok\Client;
use Pushok\Notification;
use Pushok\Payload;

class VoIPPush {
    private $client;
    private $isProduction;

    public function __construct($isProduction = false) {
        $this->isProduction = $isProduction;

        try {
            $p12Path = __DIR__ . '/../certificates/voip_push.p12';
            $p12Password = ''; // Пустой пароль

            if (!file_exists($p12Path)) {
                throw new Exception("P12 file not found: $p12Path");
            }

            $authProvider = AuthProvider\Certificate::create([
                'certificate_path' => $p12Path,
                'certificate_secret' => $p12Password
            ]);

            $this->client = new Client($authProvider, $isProduction);

            error_log("[VoIP] Client initialized (production: " . ($isProduction ? 'YES' : 'NO') . ")");

        } catch (Exception $e) {
            error_log("[VoIP] Init error: " . $e->getMessage());
            throw $e;
        }
    }

    public function sendIncomingCall($voipToken, $callId, $callerName, $callType = 'audio') {
        error_log("[VoIP] ========================================");
        error_log("[VoIP] Sending push notification");
        error_log("[VoIP] Token: " . substr($voipToken, 0, 20) . "...");
        error_log("[VoIP] Call ID: $callId");
        error_log("[VoIP] Caller: $callerName");
        error_log("[VoIP] Type: $callType");
        error_log("[VoIP] Production: " . ($this->isProduction ? 'YES' : 'NO'));
        error_log("[VoIP] ========================================");

        try {
            $payload = Payload::create()
                ->setCustomValue('callId', $callId)
                ->setCustomValue('callerName', $callerName)
                ->setCustomValue('callType', $callType)
                ->setCustomValue('timestamp', time());

            $notification = new Notification($payload, $voipToken);
            $notification->setTopic('com.securewavenew.app.voip');

            $responses = $this->client->push([$notification]);

            foreach ($responses as $response) {
                $statusCode = $response->getStatusCode();
                $apnsId = $response->getApnsId();

                error_log("[VoIP] Response: $statusCode");
                error_log("[VoIP] APNs ID: $apnsId");

                if ($statusCode === 200) {
                    error_log("[VoIP] ✅ SUCCESS!");
                    return true;
                } else {
                    $reason = $response->getReasonPhrase();
                    error_log("[VoIP] ❌ FAILED: $reason");
                    return false;
                }
            }

        } catch (Exception $e) {
            error_log("[VoIP] ❌ Exception: " . $e->getMessage());
            error_log("[VoIP] Stack trace: " . $e->getTraceAsString());
            return false;
        }

        return false;
    }
}
