<?php
ini_set('display_errors', 1);
ini_set('html_errors', 0);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

$link = mysqli_connect('localhost', 'root', '', 'openQAdb');
$result = mysqli_query($link, "SELECT * FROM test");

while($row = mysqli_fetch_assoc($result)){
    echo $row['entry'];
}

mysqli_query($link, "INSERT INTO test (entry) VALUE ('can php write this?')");

?>

