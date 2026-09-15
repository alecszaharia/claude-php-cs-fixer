<?php
namespace Fixture;
class Sample{
    public function items( $a,$b ){
        $list = array('a' => $a,'b'=>$b);
        if($a){ return $list; }
        return array();
    }
}
