<?php
    $link = mysqli_connect('localhost', 'root', '', 'openQAdb');
    $result = mysqli_query($link, "SELECT * FROM test");
    while($row = mysqli_fetch_assoc($result)){
        echo $row['entry'];
    }
    mysqli_query($link, "INSERT INTO test (entry) VALUE ('can php write this?')");
?>

