<?php

$entityId = getenv('SIMPLESAMLPHP_SP_ENTITY_ID');
$acsUrl = getenv('SIMPLESAMLPHP_SP_ASSERTION_CONSUMER_SERVICE');

if (!$entityId || !$acsUrl) {
    throw new RuntimeException('Configure the SP entity ID and ACS URL in .env.');
}

$metadata[$entityId] = [
    'AssertionConsumerService' => $acsUrl,
];
