module namespace anonymize = "https://github.com/openhie/openinfoman-anon";
import module namespace functx = "http://www.functx.com";


declare namespace csd  =  "urn:ihe:iti:csd:2013";

declare variable $anonymize:exclude_address := (
  'street',  'st',  'way',  'road',  'hwy',  'highway' , 'lane','ave','avenue', 'rd', 's', 'n', 'e','w','sw','nw','se','ne'
);

declare variable $anonymize:exclude_name := (
  'clinic','hospital','hosp','facility','health','primary','district','regional','referal','center','centre'
);

declare function anonymize:document2($src_doc,$provider_values,$organization_values,$facility_values) {
  $src_doc
};
declare function anonymize:document($src_doc,$provider_values,$organization_values,$facility_values) {
   <csd:CSD>
     <csd:organizationDirectory>
       {
	 for $org in $src_doc/csd:CSD/csd:organizationDirectory/csd:organization
	 return anonymize:organization($org,$organization_values)
       }
     </csd:organizationDirectory>
     <csd:facilityDirectory>
       {
	 for $fac in $src_doc/csd:CSD/csd:facilityDirectory/csd:facility
	 return anonymize:facility($fac,$facility_values)
       }
     </csd:facilityDirectory>
     <csd:serviceDirectory>{$src_doc/csd:CSD/csd:serviceDirectory/csd:service}</csd:serviceDirectory>
     <csd:providerDirectory>
       {
	 for $provider in $src_doc/csd:CSD/csd:providerDirectory/csd:provider
	 return anonymize:provider($provider,$provider_values,$facility_values)
       }
     </csd:providerDirectory>
   </csd:CSD>
};





declare function anonymize:scramble($source) {
  if (contains($source,'@'))
  then (:looks like email :)
    concat('someone_' , random:integer() , '@nowhere.com')
  else 
    let $tokens := functx:chars($source)
    let $all := 
    for $p in (1 to count($tokens)) 
      let $t := $tokens[$p]
      return
	if (matches($t,'\d'))
	then string(random:integer(max((0,9)))+1)
	else $t
    return string-join($all,'')

};

declare function anonymize:replace-word($source,$values) {
  anonymize:replace-word($source,$values,map {})
};

declare function anonymize:replace-word($source,$values,$map) {
  anonymize:replace-word($source,$values,$map,())
};

declare function anonymize:replace-word($source,$values,$map,$excludes) {
  let $mapped := map:get($map,$source)
  return 
    if ($mapped) 
    then $mapped 
    else if ($excludes = lower-case($source) )
    then $source
    else if (matches($source,"\d"))
    then anonymize:scramble($source)
    else 
      let $rand := random:integer(count($values)) + 1
      return $values[$rand]
};

declare function anonymize:replace-string($source,$values){
  anonymize:replace-string($source,$values,map {})
};

declare function anonymize:replace-string($source,$values,$map) {
  anonymize:replace-string($source,$values,$map,())
};

declare function anonymize:replace-string($source,$values,$map,$excludes) {
  (:tokenize the $source text on non-letters, replace with value and join:)
  let $tokens := tokenize($source,'\W+')
  let $joins := tokenize($source,'\w+')
  let $anons := 
    for $t in $tokens 
    return anonymize:replace-word($t,$values,$map,$excludes)
  let $count := max((count($anons), count($joins)))    
  let $all := 
    if (matches($source,'^\W+'))
    then
      for $p in (0 to $count) 
      return ($anons[$p],$joins[$p])
    else
      for $p in (0 to $count) 
      return ($joins[$p],$anons[$p])
  return string-join($all)

};

declare function  anonymize:organization($organization,$values) {
  anonymize:organization($organization,$values,map{})
};

declare function  anonymize:organization($organization,$values,$map) {
  copy $org  := $organization
  modify (
    let $anon_name := anonymize:replace-string($org/csd:primaryName,$values,$map ,$anonymize:exclude_name)
    return replace value of node $org/csd:primaryName with $anon_name
    ,
    for $cp in $org/csd:contactPoint
    let $anon_cp := 
      if (string($cp/@code) = 'EMAIL')
      then
        <csd:contactPoint>
          <csd:codedType code="{$cp/csd:codedType/@code}" codingScheme="{$cp/csd:codedType/@codingScheme}">someone@nowhere.com</csd:codedType>
	</csd:contactPoint> 
      else 
        <csd:contactPoint>
          <csd:codedType code="{$cp/csd:codedType/@code}" codingScheme="{$cp/csd:codedType/@codingScheme}">{anonymize:scramble($cp/csd:codedType/text())}</csd:codedType>
	</csd:contactPoint> 
    return replace node $cp with $anon_cp
    ,
    for $addr in $org/csd:address
      for $line in $addr/csd:addressLine[@component = 'streetAddress' or @component = 'StreetAddress' or @component = 'city']
      let $anon_addr := anonymize:replace-string($line/text(),$values,$map, $anonymize:exclude_address) 
      return  replace value of node $line with $anon_addr 
    ,
    for $contact_name in $org/csd:contact/csd:person/csd:name
    let $anon_name := anonymize:provider-name($contact_name,$values)
    return replace node $contact_name with $anon_name
    ,
    for $addr in $org/csd:contact/csd:person/csd:address
      for $line in $addr/csd:addressLine[@component = 'streetAddress' or @component = 'StreetAddress' or @component = 'city']
      let $anon_addr := anonymize:replace-string($line/text(),$values,$map, $anonymize:exclude_address) 
      return replace value of node $line with $anon_addr 

  )
  return $org
};





declare function  anonymize:facility($facility,$values) {
  anonymize:facility($facility,$values,map {})
};


declare function  anonymize:facility($facility,$values,$map) {
  copy $fac  := $facility
  modify (
    let $anon_name := anonymize:replace-string($fac/csd:primaryName,$values,$map,$anonymize:exclude_name)
    return replace value of node $fac/csd:primaryName with $anon_name
    ,
    for $cp in $fac/csd:contactPoint
    let $anon_cp := 
      <csd:contactPoint>
        <csd:codedType code="{$cp/csd:codedType/@code}" codingScheme="{$cp/csd:codedType/@codingScheme}">{anonymize:scramble($cp/csd:codedType/text())}</csd:codedType>
      </csd:contactPoint> 
    return replace node $cp with $anon_cp
    ,
    for $addr in $fac/csd:address
      for $line in $addr/csd:addressLine[@component = 'streetAddress' or @component = 'StreetAddress' or  @component = 'city']
      let $anon_addr :=  anonymize:replace-string($line/text(),$values,$map,$anonymize:exclude_address)
      return replace value of node $line with $anon_addr
    ,
    for $contact_name in $fac/csd:contact/csd:person/csd:name
    let $anon_name := anonymize:provider-name($contact_name,$values)
    return replace node $contact_name with $anon_name
    ,
    for $addr in $fac/csd:contact/csd:person/csd:address
      for $line in $addr/csd:addressLine[@component = 'streetAddress' or @component = 'StreetAddress' or  @component = 'city']
      let $anon_addr := anonymize:replace-string($line/text(),$values,$map, $anonymize:exclude_address)
      return replace value of node $line with $anon_addr 


  )
  return $fac
};


declare function anonymize:provider($provider,$values,$addr_values) {
  anonymize:provider($provider,$values,$addr_values,map {})
};

declare function anonymize:provider($provider,$values,$addr_values,$map) {
  copy $prov := $provider
  modify (
    for $name in $prov/csd:demographic/csd:name
    let $anon_name := anonymize:provider-name($name,$values)
    return replace node $name with $anon_name
    ,
    for $cp in $prov/csd:demographic/csd:contactPoint
      let $anon_cp := 
      <csd:contactPoint>
        <csd:codedType code="{$cp/csd:codedType/@code}" codingScheme="{$cp/csd:codedType/@codingScheme}">{anonymize:scramble($cp/csd:codedType/text())}</csd:codedType>
      </csd:contactPoint> 
      return replace node $cp with $anon_cp
    , 
    for $addr in $prov/csd:demographic/csd:address
      for $line in $addr/csd:addressLine[@component = 'streetAddress' or @component = 'StreetAddress' or @component = 'city']
      let $anon_addr := anonymize:replace-string($line/text(),$addr_values,$map, $anonymize:exclude_address) 
      return  replace value of node $line with $anon_addr 

    )
  return $prov

};




declare function anonymize:provider-name($name,$values) {
(: Example Input:
				<name>
					<commonName>Banargee, Dev</commonName>
					<honorific>Dr.</honorific>
					<forename>Dev</forename>
					<surname>Banerjee</surname>
				</name>
:)
    let $honor :=  ($name/csd:honorific)[1]/text()
    let $sur :=  ($name/csd:surname)[1]/text()
    let $fore :=  ($name/csd:foreame)[1]/text()
    let $common :=  ($name/csd:commonName)[1]/text()
    let $anon_sur := anonymize:replace-string($sur,$values)
    let $anon_fore := anonymize:replace-string($fore,$values)
     
    let $map_0 := 
      if ($honor)
      then map {$honor: $honor}
      else map {}
    let $map_1 := 
      if ($anon_sur) 
      then map:put($map_0,$sur,$anon_sur)
      else $map_0
    let $map_2 := 
      if ($anon_fore) 
      then map:put($map_0,$fore,$anon_fore)
      else $map_1

    let $anon_common := anonymize:replace-string($common,$values,$map_2)
    let $anon_name := 
      <csd:name>
         <csd:commonName>{$anon_common}</csd:commonName>
	 {if ($honor) then <csd:honorific>{$honor}</csd:honorific> else () }
	 {if ($anon_fore) then	 <csd:forename>{$anon_fore}</csd:forename> else () }
	 {if ($anon_sur) then  <csd:surname>{$anon_sur}</csd:surname> else () }
      </csd:name>
    return $anon_name
};




