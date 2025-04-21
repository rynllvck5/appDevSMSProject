<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");

require_once 'config.php';

$conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);

if ($conn->connect_error) {
    die(json_encode(["error" => "Database connection failed"]));
}

$sql = "SELECT 
          codeName, 
          firstName, 
          middleName, 
          lastName, 
          position, 
          picture 
        FROM candidate";
$result = $conn->query($sql);

$candidates = [];

if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $codeName = strtoupper($row['codeName']);
        $candidates[$codeName] = [
            'firstName' => $row['firstName'],
            'middleName' => $row['middleName'],
            'lastName' => $row['lastName'],
            'position' => $row['position'],
            'picture' => $row['picture'] ? base64_encode($row['picture']) : null
        ];
    }
}

$conn->close();
echo json_encode($candidates);
?>