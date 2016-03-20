import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_lsc = "https://github.com/openhie/openinfoman/csd_lsc";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
import module namespace anonymize = "https://github.com/openhie/openinfoman-anon";
import module namespace functx = "http://www.functx.com";

declare namespace csd  =  "urn:ihe:iti:csd:2013";

declare variable $careServicesRequest as item() external;

let $dest_doc := /.
let $dest := $careServicesRequest/@resource

let $values_doc := "anonymous/bible.xml"
let $fac_values_doc := "anonymous/star.xml"


let $values_src_0 := db:open($csd_webconf:db,$values_doc)
let $values_src_1 := 
 if (count($values_src_0//value[1]) > 0)  
 then $values_src_0
 else 
   let $number-for-a := string-to-codepoints('A')
   let $number-for-z := string-to-codepoints('Z')

   let $values_src := 
     <values>
       {
	 for $letter in ($number-for-a to $number-for-z)
	 let $url := concat('http://en.wikipedia.org/wiki/List_of_biblical_names_starting_with_', codepoints-to-string($letter))
	 let $resp := http:send-request(<http:request method='get' href="{$url}"/>)
 	   for $li in $resp/html/body//div[@id="mw-content-text"]/ul[1]/li
	   let $text := string-join(($li/a[1]/text(),$li/text()))
	   let $name := tokenize($text,'\W+')[1]
	   return <value>{functx:trim($name)}</value>
       }
     </values>
    return $values_src
let $values := $values_src_1//value/text()
  


let $fac_values_src_0 := db:open($csd_webconf:db,  $fac_values_doc)
let $fac_values_src_1 := 
 if (count($fac_values_src_0//value[1]) > 0)  
 then $fac_values_src_0
 else 
   let $fac_url := 'http://en.wikipedia.org/wiki/List_of_proper_names_of_stars_in_alphabetical_order'
   let $resp := http:send-request(<http:request method='get' href="{$fac_url}"/>)
  
   return
     <values>
       {
	 for $td in $resp//table[@class="wikitable"]//td[1]
	 let $text := 
	   functx:trim(string-join(($td/a[1]/text(),$td/text())))
	 return if ($text) then <value>{$text}</value> else ()
       }
     </values>


let $fac_values := $fac_values_src_1//value/text()
 

return 
(
  if (count($values_src_0//value[1]) = 0)  
  then 
     if (db:exists($csd_webconf:db, $values_doc))
     then db:replace($csd_webconf:db, $values_src_1, $values_doc)
     else db:add($csd_webconf:db, $values_src_1, $values_doc)
  else ()
  ,
  if (count($fac_values_src_0//value[1]) = 0)  
  then 
     if (db:exists($csd_webconf:db, $fac_values_doc))
     then db:replace($csd_webconf:db, $fac_values_src_1, $fac_values_doc)
     else db:add($csd_webconf:db, $fac_values_src_1, $fac_values_doc)
  else ()
  ,
  for $doc  in $careServicesRequest/documents/document
    let $name := $doc/@resource
    let $src_doc :=
      if (not ($name = $dest)) then csd_dm:open_document( $name) 
      else ()
    let $anon_doc := anonymize:document($src_doc,$values,$fac_values,$fac_values)
    return   (csd_lsc:refresh_doc($dest_doc, $anon_doc))

)
