<?php
require __DIR__ . '/vendor/autoload.php';
use Brick\Math\BigInteger;
$n1 = BigInteger::of(123456);
$n2 = BigInteger::of(789101);
$sum = $n1->plus($n2);
echo "sum".$sum;
?>
