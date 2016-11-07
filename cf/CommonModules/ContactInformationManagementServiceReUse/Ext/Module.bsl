////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// The Contact information subsystem.
// 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Defines if there the AddresClassifier subsystem is available and there are records
// about states in the AddressObjects information register.
//
Function AddressClassifierAvailable() Export
	ThereIsClassifier = CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier");
	If ThereIsClassifier AND Not CommonUseReUse.DataSeparationEnabled() Then
		ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
		ModuleAddressClassifierService.CheckInitialFilling();
	EndIf;
	
	Return ThereIsClassifier;
EndFunction

// Conversion for the values list leaving only the last values of the key=value pairs.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_UniqueByPresentationInList() Export
	
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://v8.1c.en/8.1/data/core""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|
		|  <xsl:template match=""//tns:ValueListType/tns:item"">
		|    <xsl:variable name=""presentation"" select=""string(tns:presentation)"" />
		|    <xsl:if test=""0=count(following-sibling::tns:item[tns:presentation=$presentation])"" >
		|      <xsl:copy-of select=""."" />
		|    </xsl:if>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
		
	Return Converter;
EndFunction

// Conversion for comparison of two XML rows.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_ValuesTableXMLDifferences() Export
	Converter = New XSLTransform;
	
	// Names space must be empty.
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0""
		|  xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:xs=""http://www.w3.org/2001/XMLSchema""
		|
		|  xmlns:str=""http://exslt.org/strings""
		|  xmlns:exsl=""http://exslt.org/common""
		|
		|  extension-element-prefixes=""str exsl""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_RowFunctionsTemplates() + "
		|" + XSLT_XPathFunctionsTemplates() + "
		|  
		|  <!-- parce tree elements to xpath-value -->
		|  <xsl:template match=""node()"" mode=""action"">
		|    
		|    <xsl:variable name=""text"">
		|      <xsl:call-template name=""str-trim-all"">
		|        <xsl:with-param name=""str"" select=""text()"" />
		|      </xsl:call-template>
		|    </xsl:variable>
		|  
		|    <xsl:if test=""$text!=''"">
		|      <xsl:element name=""item"">
		|        <xsl:attribute name=""path"">
		|          <xsl:variable name=""tmp-path"">
		|            <xsl:call-template name=""build-path"" />
		|          </xsl:variable>
		|          <xsl:value-of select=""substring($tmp-path, 6)"" /> <!-- pass '/dn/f' or '/dn/s' -->
		|        </xsl:attribute>
		|        <xsl:attribute name=""value"">
		|          <xsl:value-of select=""text()"" />
		|        </xsl:attribute>
		|      </xsl:element>
		|    </xsl:if>
		|  
		|    <xsl:apply-templates select=""@* | node()"" mode=""action""/>
		|  </xsl:template>
		|  
		|  <!-- parce tree attributes to xpath-value -->
		|  <xsl:template match=""@*"" mode=""action"">
		|    <xsl:element name=""item"">
		|      <xsl:attribute name=""path"">
		|          <xsl:variable name=""tmp-path"">
		|            <xsl:call-template name=""build-path"" />
		|          </xsl:variable>
		|          <xsl:value-of select=""substring($tmp-path, 6)"" /> <!-- pass '/dn/f' or '/dn/s' -->
		|      </xsl:attribute>
		|      <xsl:attribute name=""value"">
		|        <xsl:value-of select=""."" />
		|      </xsl:attribute>
		|    </xsl:element>
		|  </xsl:template>
		|  
		|  <!-- main -->
		|  <xsl:variable name=""dummy"">
		|    <xsl:element name=""first"">
		|      <xsl:apply-templates select=""/dn/f"" mode=""action"" />
		|    </xsl:element> 
		|    <xsl:element name=""second"">
		|      <xsl:apply-templates select=""/dn/s"" mode=""action"" />
		|    </xsl:element>
		|  </xsl:variable>
		|  <xsl:variable name=""dummy-nodeset"" select=""exsl:node-set($dummy)"" />
		|  <xsl:variable name=""first-items"" select=""$dummy-nodeset/first/item"" />
		|  <xsl:variable name=""second-items"" select=""$dummy-nodeset/second/item"" />
		|  
		|  <xsl:template match=""/"">
		|    
		|    <!-- first vs second -->
		|    <xsl:variable name=""first-second"">
		|      <xsl:for-each select=""$first-items"">
		|        <xsl:call-template name=""compare"">
		|          <xsl:with-param name=""check"" select=""$second-items"" />
		|        </xsl:call-template>
		|      </xsl:for-each>
		|    </xsl:variable>
		|    <xsl:variable name=""first-second-nodeset"" select=""exsl:node-set($first-second)"" />
		|  
		|    <!-- second vs first without doubles -->
		|    <xsl:variable name=""doubles"" select=""$first-second-nodeset/item"" />
		|    <xsl:variable name=""second-first"">
		|      <xsl:for-each select=""$second-items"">
		|        <xsl:call-template name=""compare"">
		|          <xsl:with-param name=""check"" select=""$first-items"" />
		|          <xsl:with-param name=""doubles"" select=""$doubles"" />
		|        </xsl:call-template>
		|      </xsl:for-each>
		|    </xsl:variable>
		|      
		|    <!-- result -->
		|    <ValueTable xmlns=""http://v8.1c.en/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xsi:type=""ValueTable"">
		|      <column>
		|        <Name xsi:type=""xs:string"">Path</Name>
		|        <ValueType>
		|           <Type>xs:string</Type>
		|           <StringQualifiers><Length>0</Length><AllowedLength>Variable</AllowedLength></StringQualifiers>
		|        </ValueType>
		|      </column>
		|      <column>
		|        <Name xsi:type=""xs:string"">Value1</Name>
		|        <ValueType>
		|           <Type>xs:string</Type>
		|           <StringQualifiers><Length>0</Length><AllowedLength>Variable</AllowedLength></StringQualifiers>
		|        </ValueType>
		|      </column>
		|      <column>
		|        <Name xsi:type=""xs:string"">Value2</Name>
		|        <ValueType>
		|           <Type>xs:string</Type>
		|           <StringQualifiers><Length>0</Length><AllowedLength>Variable</AllowedLength></StringQualifiers>
		|        </ValueType>
		|      </column>
		|  
		|      <xsl:for-each select=""$first-second-nodeset/item | exsl:node-set($second-first)/item"">
		|        <xsl:element name=""row"">
		|           <xsl:element name=""Value"">
		|             <xsl:value-of select=""@path""/>
		|           </xsl:element>
		|           <xsl:element name=""Value"">
		|             <xsl:value-of select=""@value1""/>
		|           </xsl:element>
		|           <xsl:element name=""Value"">
		|             <xsl:value-of select=""@value2""/>
		|           </xsl:element>
		|        </xsl:element>
		|      </xsl:for-each>
		|  
		|    </ValueTable>
		|  
		|  </xsl:template>
		|  <!-- /main -->
		|  
		|  <!-- compare sub -->
		|  <xsl:template name=""compare"">
		|    <xsl:param name=""check"" />
		|    <xsl:param name=""doubles"" select=""/.."" />
		|    
		|    <xsl:variable name=""path""  select=""@path""/>
		|    <xsl:variable name=""value"" select=""@value""/>
		|    <xsl:variable name=""diff""  select=""$check[@path=$path]""/>
		|    <xsl:choose>
		|      <xsl:when test=""count($diff)=0"">
		|        <xsl:if test=""count($doubles[@path=$path and @value1='' and @value2=$value])=0"">
		|          <xsl:element name=""item"">
		|            <xsl:attribute name=""path"">   <xsl:value-of select=""$path""/> </xsl:attribute>
		|            <xsl:attribute name=""value1""> <xsl:value-of select=""$value""/> </xsl:attribute>
		|            <xsl:attribute name=""value2"" />
		|          </xsl:element>
		|        </xsl:if>
		|      </xsl:when>
		|      <xsl:otherwise>
		|  
		|        <xsl:for-each select=""$diff[@value!=$value]"">
		|            <xsl:variable name=""diff-value"" select=""@value""/>
		|            <xsl:if test=""count($doubles[@path=$path and @value1=$diff-value and @value2=$value])=0"">
		|              <xsl:element name=""item"">
		|                <xsl:attribute name=""path"">   <xsl:value-of select=""$path""/>  </xsl:attribute>
		|                <xsl:attribute name=""value1""> <xsl:value-of select=""$value""/> </xsl:attribute>
		|                <xsl:attribute name=""value2""> <xsl:value-of select=""@value""/> </xsl:attribute>
		|              </xsl:element>
		|            </xsl:if>
		|        </xsl:for-each>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|  
		|</xsl:stylesheet>
		|");
		
	Return Converter;
EndFunction

// Conversion for the text with the Key=Value pairs separated by line breaks (see the address format) to XML.
// In case there are repeated keys, they are all included into the result, but the last one will be used during deserialization (a special feature of a platform serializer).
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_KeyValueOfRowInStructure() Export
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0""
		|  xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:str=""http://exslt.org/strings""
		|  extension-element-prefixes=""str""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_RowFunctionsTemplates() + "
		|
		|  <xsl:template match=""ExternalParamNode"">
		|
		|    <xsl:variable name=""source"">
		|      <xsl:call-template name=""str-replace-all"">
		|        <xsl:with-param name=""str"" select=""."" />
		|        <xsl:with-param name=""search-for"" select=""'&#10;&#09;'"" />
		|        <xsl:with-param name=""replace-by"" select=""'&#13;'"" />
		|      </xsl:call-template>
		|    </xsl:variable>
		|
		|    <Structure xmlns=""http://v8.1c.en/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Structure"">
		|
		|     <xsl:for-each select=""str:tokenize($source, '&#10;')"" >
		|       <xsl:if test=""contains(., '=')"">
		|
		|         <xsl:element name=""Property"">
		|           <xsl:attribute name=""name"" >
		|             <xsl:call-template name=""str-trim-all"">
		|               <xsl:with-param name=""str"" select=""substring-before(., '=')"" />
		|             </xsl:call-template>
		|           </xsl:attribute>
		|
		|           <Value xsi:type=""xs:string"">
		|             <xsl:call-template name=""str-replace-all"">
		|               <xsl:with-param name=""str"" select=""substring-after(., '=')"" />
		|               <xsl:with-param name=""search-for"" select=""'&#13;'"" />
		|               <xsl:with-param name=""replace-by"" select=""'&#10;'"" />
		|             </xsl:call-template>
		|           </Value>
		|
		|         </xsl:element>
		|
		|       </xsl:if>
		|     </xsl:for-each>
		|
		|    </Structure>
		|
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");

	Return Converter;
EndFunction

// Conversion for the text with the Key=Value pairs separated by line breaks (see the address format) to XML.
// In case of repeated keys, everything is included to the result.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_StringKeyOfValueInValueList() Export
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0""
		|  xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:str=""http://exslt.org/strings""
		|  extension-element-prefixes=""str""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_RowFunctionsTemplates() + "
		|
		|  <xsl:template match=""ExternalParamNode"">
		|
		|    <xsl:variable name=""source"">
		|      <xsl:call-template name=""str-replace-all"">
		|        <xsl:with-param name=""str"" select=""."" />
		|        <xsl:with-param name=""search-for"" select=""'&#10;&#09;'"" />
		|        <xsl:with-param name=""replace-by"" select=""'&#13;'"" />
		|      </xsl:call-template>
		|    </xsl:variable>
		|
		|    <ValueListType xmlns=""http://v8.1c.en/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""ValueListType"">
		|    <valueType/>
		|
		|      <xsl:for-each select=""str:tokenize($source, '&#10;')"" >
		|        <xsl:if test=""contains(., '=')"">
		|
		|          <item>
		|            <value xsi:type=""xs:string"">
		|              <xsl:call-template name=""str-replace-all"">
		|                <xsl:with-param name=""str"" select=""substring-after(., '=')"" />
		|                <xsl:with-param name=""search-for"" select=""'&#13;'"" />
		|                <xsl:with-param name=""replace-by"" select=""'&#10;'"" />
		|              </xsl:call-template>
		|            </value>
		|            <presentation>
		|              <xsl:call-template name=""str-trim-left"">
		|                <xsl:with-param name=""str"" select=""substring-before(., '=')"" />
		|              </xsl:call-template>
		|            </presentation>
		|          </item>
		|
		|        </xsl:if>
		|      </xsl:for-each>
		|
		|    </ValueListType >
		|
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");

	Return Converter;
EndFunction

// Conversion for the values list to the row of the key=value pairs separated by line break.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_ValueListIntoStringKeyValue() Export
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://v8.1c.en/8.1/data/core""
		|>
		|<xsl:output method=""text"" encoding=""utf-8""/>
		|" + XSLT_RowFunctionsTemplates() + "
		|  
		|  <xsl:template match=""/"">
		|    <xsl:apply-templates select=""//tns:ValueListType/tns:item"" />
		|  </xsl:template>
		|  
		|  <xsl:template match=""//tns:ValueListType/tns:item"">
		|
		|    <xsl:call-template name=""str-trim-all"">
		|      <xsl:with-param name=""str"" select=""tns:presentation"" />
		|    </xsl:call-template>
		|    <xsl:text/>=<xsl:text/>
		|
		|    <xsl:call-template name=""str-replace-all"">
		|      <xsl:with-param name=""str"" select=""tns:value"" />
		|      <xsl:with-param name=""search-for"" select=""'&#10;'"" />
		|      <xsl:with-param name=""replace-by"" select=""'&#10;&#09;'"" />
		|    </xsl:call-template>
		|
		|    <xsl:if test=""position()!=last()"">
		|      <xsl:text/>
		|        <xsl:value-of select=""'&#10;'""/>
		|      <xsl:text/>
		|    </xsl:if>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Conversion for structure to row of key=value pairs separated by line break.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_StructureToStringKeyValue() Export
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://v8.1c.en/8.1/data/core""
		|>
		|<xsl:output method=""text"" encoding=""utf-8""/>
		|" + XSLT_RowFunctionsTemplates() + "
		|
		|  <xsl:template match=""/"">
		|    <xsl:apply-templates select=""//tns:Structure/tns:Property"" />
		|  </xsl:template>
		|
		|  <xsl:template match=""//tns:Property"">
		|
		|    <xsl:value-of select=""@name"" />
		|    <xsl:text/>=<xsl:text/>
		|
		|    <xsl:call-template name=""str-replace-all"">
		|      <xsl:with-param name=""str"" select=""tns:Value"" />
		|      <xsl:with-param name=""search-for"" select=""'&#10;'"" />
		|      <xsl:with-param name=""replace-by"" select=""'&#10;&#09;'"" />
		|    </xsl:call-template>
		|
		|    <xsl:if test=""position()!=last()"">
		|      <xsl:text/>
		|        <xsl:value-of select=""'&#10;'""/>
		|      <xsl:text/>
		|    </xsl:if>
		|  </xsl:template>
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Conversion for the values list to the structure. Presentation is converted to key.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_ValueListInStructure() Export
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.en/8.1/data/core""
		|  xmlns=""http://v8.1c.en/8.1/data/core""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_RowFunctionsTemplates() + "
		|
		|  <xsl:template match=""/"">
		|    <Structure xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Structure"">
		|      <xsl:apply-templates select=""//tns:ValueListType/tns:item"" />
		|    </Structure >
		|  </xsl:template>
		|
		|  <xsl:template match=""//tns:ValueListType/tns:item"">
		|    <xsl:element name=""Property"">
		|      <xsl:attribute name=""name"">
		|        <xsl:call-template name=""str-trim-all"">
		|          <xsl:with-param name=""str"" select=""tns:presentation"" />
		|        </xsl:call-template>
		|      </xsl:attribute>
		|
		|      <xsl:element name=""Value"">
		|        <xsl:attribute name=""xsi:type"">
		|          <xsl:value-of select=""tns:value/@xsi:type""/>  
		|        </xsl:attribute>
		|        <xsl:value-of select=""tns:value""/>  
		|      </xsl:element>
		|
		|    </xsl:element>
		|</xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Conversion for structure to the values list. Key is converted to presentation.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_StructureInValueList() Export
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.en/8.1/data/core""
		|  xmlns=""http://v8.1c.en/8.1/data/core""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_RowFunctionsTemplates() + "
		|
		|  <xsl:template match=""/"">
		|    <ValueListType xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""ValueListType"">
		|      <valueType/>
		|        <xsl:apply-templates select=""//tns:Structure/tns:Property"" />
		|    </ValueListType>
		|  </xsl:template>
		|
		|  <xsl:template match=""//tns:Property"">
		|    <item>
		|      <value xsi:type=""xs:string"">
		|        <xsl:value-of select=""tns:Value"" />
		|      </value>
		|      <presentation>
		|        <xsl:value-of select=""@name"" />
		|      </presentation>
		|    </item>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Conversion for match to structure. Key is converted to key, value - in value.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_MatchInStructure() Export
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.en/8.1/data/core""
		|  xmlns=""http://v8.1c.en/8.1/data/core""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_RowFunctionsTemplates() + "
		|
		|  <xsl:template match=""/"">
		|    <Structure xmlns=""http://v8.1c.en/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Structure"">
		|      <xsl:apply-templates select=""//tns:Map/tns:pair"" />
		|    </Structure >
		|  </xsl:template>
		|  
		|  <xsl:template match=""//tns:Map/tns:pair"">
		|  <xsl:element name=""Property"">
		|    <xsl:attribute name=""name"">
		|      <xsl:call-template name=""str-trim-all"">
		|        <xsl:with-param name=""str"" select=""tns:Key"" />
		|      </xsl:call-template>
		|    </xsl:attribute>
		|  
		|    <xsl:element name=""Value"">
		|      <xsl:attribute name=""xsi:type"">
		|        <xsl:value-of select=""tns:Value/@xsi:type""/>  
		|      </xsl:attribute>
		|        <xsl:value-of select=""tns:Value""/>  
		|      </xsl:element>
		|  
		|    </xsl:element>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Removes description <?xml...> to include to another XML.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_DeleteXMLDescription() Export
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform"">
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Conversion for the contact information as XML (see the XDTO
// ContactInformation pack) to enumeration ContactInformationType.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_ContactInformationTypeByXMLRow() Export
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:ci=""http://www.v8.1c.ru/ssl/contactinfo""
		|>
		|  <xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|
		|  <xsl:template match=""/"">
		|    <EnumRef.ContactInformationTypes xmlns=""http://v8.1c.ru/8.1/data/enterprise/current-config"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""EnumRef.ContactInformationTypes"">
		|      <xsl:call-template name=""enum-by-type"" >
		|        <xsl:with-param name=""type"" select=""ci:ContactInformation/ci:Content/@xsi:type"" />
		|      </xsl:call-template>
		|    </EnumRef.ContactInformationTypes>
		|  </xsl:template>
		|
		|  <xsl:template name=""enum-by-type"">
		|    <xsl:param name=""type"" />
		|    <xsl:choose>
		|      <xsl:when test=""$type='Address'"">
		|        <xsl:text>Address</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='PhoneNumber'"">
		|        <xsl:text>Phone</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='FaxNumber'"">
		|        <xsl:text>Fax</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='EMail'"">
		|        <xsl:text>EmailAddress</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='WebSite'"">
		|        <xsl:text>WebPage</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='Other'"">
		|        <xsl:text>Other</xsl:text>
		|      </xsl:when>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Conversion for XML differences table depending on the contact information type.
//
// Parameters:
//    ContactInformationType - String, EnumRef.ContactInformationTypes - name and enumeration value.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_InterpretingDifferencesXMLContactInformation(Val ContactInformationType) Export
	
	If TypeOf(ContactInformationType) <> Type("String") Then
		ContactInformationType = ContactInformationType.Metadata().Name;
	EndIf;
	
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:ci=""http://www.v8.1c.ru/ssl/contactinfo""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  <xsl:param name=""target-type"" select=""'" + ContactInformationType + "'""/>
		|
		|  <xsl:template match=""/"">
		|    <xsl:choose>
		|      <xsl:when test=""$target-type='Address'"">
		|         <xsl:apply-templates select=""."" mode=""action-address""/>
		|      </xsl:when>
		|      <xsl:otherwise>
		|         <xsl:apply-templates select=""."" mode=""action-copy""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:template match=""node() | @*"" mode=""action-copy"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" mode=""action-copy""/>
		|    </xsl:copy>
		|  </xsl:template>
		|
		|  <xsl:template match=""node() | @*"" mode=""action-address"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" mode=""action-address""/>
		|    </xsl:copy>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Returns XSL converter for conversion of the structure to the contact information as XML.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_XSLTransform() Export
	
	AdditionalAddressItemsCodes = New TextDocument;
	For Each AdditionalAddressItem In ContactInformationManagementClientServerReUse.TypesOfAddressingAddressesRF() Do
		AdditionalAddressItemsCodes.AddLine("<data:item data:title=""" + AdditionalAddressItem.Description + """>" + AdditionalAddressItem.Code + "</data:item>");
	EndDo;
	
	CodesOfStates = New TextDocument;
	AllStates = ContactInformationManagementService.AllStates();
	If AllStates <> Undefined Then
		For Each String In AllStates Do
			CodesOfStates.AddLine("<data:item data:code=""" + Format(String.RFTerritorialEntityCode, "NZ=; NG=") + """>" 
				+ String.Presentation + "</data:item>");
		EndDo;
	EndIf;
	
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:xs=""http://www.w3.org/2001/XMLSchema""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|
		|  xmlns:data=""http://www.v8.1c.ru/ssl/contactinfo""
		|
		|  xmlns:exsl=""http://exslt.org/common""
		|  extension-element-prefixes=""exsl""
		|  exclude-result-prefixes=""data tns""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  " + XSLT_RowFunctionsTemplates() + "
		|  
		|  <xsl:variable name=""local-country"">RUSSIA</xsl:variable>
		|
		|  <xsl:variable name=""presentation"" select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()"" />
		|  
		|  <xsl:template match=""/"">
		|    <ContactInformation>
		|
		|      <xsl:attribute name=""Presentation"">
		|        <xsl:value-of select=""$presentation""/>
		|      </xsl:attribute> 
		|      <xsl:element name=""Comment"">
		|       <xsl:value-of select=""tns:Structure/tns:Property[@name='Comment']/tns:Value/text()""/>
		|      </xsl:element>
		|
		|      <xsl:element name=""Content"">
		|        <xsl:attribute name=""xsi:type"">Address</xsl:attribute>
		|        <xsl:variable name=""country"" select=""tns:Structure/tns:Property[@name='Country']/tns:Value/text()""></xsl:variable>
		|        <xsl:variable name=""country-upper"">
		|          <xsl:call-template name=""str-upper"">
		|            <xsl:with-param name=""str"" select=""$country"" />
		|          </xsl:call-template>
		|        </xsl:variable>
		|
		|        <xsl:attribute name=""Country"">
		|          <xsl:choose>
		|            <xsl:when test=""0=count($country)"">
		|              <xsl:value-of select=""$local-country"" />
		|            </xsl:when>
		|            <xsl:otherwise>
		|              <xsl:value-of select=""$country"" />
		|            </xsl:otherwise> 
		|          </xsl:choose>
		|        </xsl:attribute>
		|
		|        <xsl:choose>
		|          <xsl:when test=""0=count($country)"">
		|            <xsl:apply-templates select=""/"" mode=""domestic"" />
		|          </xsl:when>
		|          <xsl:when test=""$country-upper=$local-country"">
		|            <xsl:apply-templates select=""/"" mode=""domestic"" />
		|          </xsl:when>
		|          <xsl:otherwise>
		|            <xsl:apply-templates select=""/"" mode=""foreign"" />
		|          </xsl:otherwise> 
		|        </xsl:choose>
		|
		|      </xsl:element>
		|    </ContactInformation>
		|  </xsl:template>
		|  
		|  <xsl:template match=""/"" mode=""foreign"">
		|    <xsl:element name=""Content"">
		|      <xsl:attribute name=""xsi:type"">xs:string</xsl:attribute>
		|
		|      <xsl:variable name=""value"" select=""tns:Structure/tns:Property[@name='Value']/tns:Value/text()"" />        
		|      <xsl:choose>
		|        <xsl:when test=""0=count($value)"">
		|          <xsl:value-of select=""$presentation"" />
		|        </xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select=""$value"" />
		|        </xsl:otherwise> 
		|      </xsl:choose>
		|    
		|    </xsl:element>
		|  </xsl:template>
		|  
		|  <xsl:template match=""/"" mode=""domestic"">
		|    <xsl:element name=""Content"">
		|      <xsl:attribute name=""xsi:type"">AddressRF</xsl:attribute>
		|    
		|      <xsl:element name=""RFTerritorialEntity"">
		|        <xsl:variable name=""value"" select=""tns:Structure/tns:Property[@name='State']/tns:Value/text()"" />
		|
		|        <xsl:choose>
		|          <xsl:when test=""0=count($value)"">
		|            <xsl:variable name=""regioncode"" select=""tns:Structure/tns:Property[@name='StateCode']/tns:Value/text()""/>
		|            <xsl:variable name=""regiontitle"" select=""$enum-regioncode-nodes/data:item[@data:code=number($regioncode)]"" />
		|              <xsl:if test=""0!=count($regiontitle)"">
		|                <xsl:value-of select=""$regiontitle""/>
		|              </xsl:if>
		|          </xsl:when>
		|          <xsl:otherwise>
		|            <xsl:value-of select=""$value"" />
		|          </xsl:otherwise> 
		|        </xsl:choose>
		|
		|      </xsl:element>
		|   
		|      <xsl:element name=""District"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='District']/tns:Value/text()""/>
		|      </xsl:element>
		|
		|      <xsl:element name=""PrRayMO"">
		|        <xsl:element name=""Region"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='Region']/tns:Value/text()""/>
		|        </xsl:element>
		|      </xsl:element>
		|  
		|      <xsl:element name=""City"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='City']/tns:Value/text()""/>
		|      </xsl:element>
		|    
		|      <xsl:element name=""UrbDistrict"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='UrbDistrict']/tns:Value/text()""/>
		|      </xsl:element>
		|
		|      <xsl:element name=""Settlement"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Settlement']/tns:Value/text()""/>
		|      </xsl:element>
		|
		|      <xsl:element name=""Street"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Street']/tns:Value/text()""/>
		|      </xsl:element>
		|
		|      <xsl:variable name=""index"" select=""tns:Structure/tns:Property[@name='IndexOf']/tns:Value/text()"" />
		|      <xsl:if test=""0!=count($index)"">
		|        <xsl:element name=""AddEMailAddress"">
		|          <xsl:attribute name=""TypeAdrEl"">" + ContactInformationManagementClientServerReUse.SerializationCodePostalIndex() + "</xsl:attribute>
		|          <xsl:attribute name=""Value""><xsl:value-of select=""$index""/></xsl:attribute>
		|        </xsl:element>
		|      </xsl:if>
		|
		|      <xsl:call-template name=""add-elem-number"">
		|        <xsl:with-param name=""source"" select=""tns:Structure/tns:Property[@name='HouseType']/tns:Value/text()"" />
		|        <xsl:with-param name=""defsrc"" select=""'House'"" />
		|        <xsl:with-param name=""value""  select=""tns:Structure/tns:Property[@name='House']/tns:Value/text()"" />
		|      </xsl:call-template>
		|
		|      <xsl:call-template name=""add-elem-number"">
		|        <xsl:with-param name=""source"" select=""tns:Structure/tns:Property[@name='BlockType']/tns:Value/text()"" />
		|        <xsl:with-param name=""defsrc"" select=""'Block'"" />
		|        <xsl:with-param name=""value""  select=""tns:Structure/tns:Property[@name='Block']/tns:Value/text()"" />
		|      </xsl:call-template>
		|
		|      <xsl:call-template name=""add-elem-number"">
		|        <xsl:with-param name=""source"" select=""tns:Structure/tns:Property[@name='ApartmentType']/tns:Value/text()"" />
		|        <xsl:with-param name=""defsrc"" select=""'Apartment'"" />
		|        <xsl:with-param name=""value""  select=""tns:Structure/tns:Property[@name='Apartment']/tns:Value/text()"" />
		|      </xsl:call-template>
		|    
		|    </xsl:element>
		|  </xsl:template>
		|
		|  <xsl:param name=""enum-codevalue"">
		|" + AdditionalAddressItemsCodes.GetText() + "
		|  </xsl:param>
		|  <xsl:variable name=""enum-codevalue-nodes"" select=""exsl:node-set($enum-codevalue)"" />
		|
		|  <xsl:param name=""enum-regioncode"">
		|" + CodesOfStates.GetText() + "
		|  </xsl:param>
		|  <xsl:variable name=""enum-regioncode-nodes"" select=""exsl:node-set($enum-regioncode)"" />
		|  
		|  <xsl:template name=""add-elem-number"">
		|    <xsl:param name=""source"" />
		|    <xsl:param name=""defsrc"" />
		|    <xsl:param name=""value"" />
		|  
		|    <xsl:if test=""0!=count($value)"">
		|  
		|      <xsl:choose>
		|        <xsl:when test=""0!=count($source)"">
		|          <xsl:variable name=""type-code"" select=""$enum-codevalue-nodes/data:item[@data:title=$source]"" />
		|          <xsl:element name=""AddEMailAddress"">
		|            <xsl:element name=""Number"">
		|              <xsl:attribute name=""Type""><xsl:value-of select=""$type-code"" /></xsl:attribute>
		|              <xsl:attribute name=""Value""><xsl:value-of select=""$value""/></xsl:attribute>
		|            </xsl:element>
		|          </xsl:element>
		|  
		|        </xsl:when>
		|        <xsl:otherwise>
		|          <xsl:variable name=""type-code"" select=""$enum-codevalue-nodes/data:item[@data:title=$defsrc]"" />
		|          <xsl:element name=""AddEMailAddress"">
		|            <xsl:element name=""Number"">
		|              <xsl:attribute name=""Type""><xsl:value-of select=""$type-code"" /></xsl:attribute>
		|              <xsl:attribute name=""Value""><xsl:value-of select=""$value""/></xsl:attribute>
		|            </xsl:element>
		|          </xsl:element>
		|  
		|        </xsl:otherwise>
		|      </xsl:choose>
		|  
		|    </xsl:if>
		|  
		|  </xsl:template>
		|  
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Converts serialized structure to contact information as XML.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_StructureToEmailAddress() Export
	Return XSLT_StructuteToRowContent("Email");
EndFunction

// Converts serialized structure to contact information as XML.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_StructureIntoWebPage() Export
	Return XSLT_StructuteToRowContent("WebSite");
EndFunction

// Converts serialized structure to contact information as XML.
//
Function XSLT_StructureInPhone() Export
	Return XSLT_StructureToPhoneFax("PhoneNumber");
EndFunction

// Converts serialized structure to contact information as XML.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_StructureInFax() Export
	Return XSLT_StructureToPhoneFax("FaxNumber");
EndFunction

// Converts serialized structure to contact information as XML.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_StructureToOther() Export
	Return XSLT_StructuteToRowContent("Other");
EndFunction

// Common conversion of the serialized structure to the contact information as XML of a simple type.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_StructuteToRowContent(Val NameXDTOType)
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  
		|<xsl:template match=""/"">
		|  
		|  <xsl:element name=""ContactInformation"">
		|  
		|  <xsl:attribute name=""Presentation"">
		|    <xsl:value-of select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()""/>
		|  </xsl:attribute> 
		|  <xsl:element name=""Comment"">
		|    <xsl:value-of select=""tns:Structure/tns:Property[@name='Comment']/tns:Value/text()""/>
		|  </xsl:element>
		|  
		|  <xsl:element name=""Content"">
		|    <xsl:attribute name=""xsi:type"">" + NameXDTOType + "</xsl:attribute>
		|    <xsl:attribute name=""Value"">
		|    <xsl:choose>
		|      <xsl:when test=""0=count(tns:Structure/tns:Property[@name='Value'])"">
		|      <xsl:value-of select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()""/>
		|      </xsl:when>
		|      <xsl:otherwise>
		|      <xsl:value-of select=""tns:Structure/tns:Property[@name='Value']/tns:Value/text()""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|    </xsl:attribute>
		|    
		|  </xsl:element>
		|  </xsl:element>
		|  
		|</xsl:template>
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Common conversion for phone and fax.
//
// Returns:
//     XSLTransform  - prepared object.
//
Function XSLT_StructureToPhoneFax(Val NameXDTOType) Export
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  <xsl:template match=""/"">
		|
		|    <xsl:element name=""ContactInformation"">
		|
		|      <xsl:attribute name=""Presentation"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()""/>
		|      </xsl:attribute> 
		|      <xsl:element name=""Comment"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Comment']/tns:Value/text()""/>
		|      </xsl:element>
		|      <xsl:element name=""Content"">
		|        <xsl:attribute name=""xsi:type"">" + NameXDTOType + "</xsl:attribute>
		|
		|        <xsl:attribute name=""CountryCode"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='CountryCode']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|        <xsl:attribute name=""CityCode"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='CityCode']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|        <xsl:attribute name=""Number"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='PhoneNumber']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|        <xsl:attribute name=""Supplementary"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='Supplementary']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|
		|      </xsl:element>
		|    </xsl:element>
		|
		|  </xsl:template>
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// XSL fragment with procedures for rows processor.
//
// Returns:
//     String - XML fragment for using in conversion.
//
Function XSLT_RowFunctionsTemplates()
	Return "
		|<!-- string functions -->
		|
		|  <xsl:template name=""str-trim-left"">
		|    <xsl:param name=""str"" />
		|    <xsl:variable name=""head"" select=""substring($str, 1, 1)""/>
		|    <xsl:variable name=""tail"" select=""substring($str, 2)""/>
		|    <xsl:choose>
		|      <xsl:when test=""(string-length($str) > 0) and (string-length(normalize-space($head)) = 0)"">
		|        <xsl:call-template name=""str-trim-left"">
		|          <xsl:with-param name=""str"" select=""$tail""/>
		|        </xsl:call-template>
		|      </xsl:when>
		|      <xsl:otherwise>
		|        <xsl:value-of select=""$str""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-trim-right"">
		|    <xsl:param name=""str"" />
		|    <xsl:variable name=""head"" select=""substring($str, 1, string-length($str) - 1)""/>
		|    <xsl:variable name=""tail"" select=""substring($str, string-length($str))""/>
		|    <xsl:choose>
		|      <xsl:when test=""(string-length($str) > 0) and (string-length(normalize-space($tail)) = 0)"">
		|        <xsl:call-template name=""str-trim-right"">
		|          <xsl:with-param name=""str"" select=""$head""/>
		|        </xsl:call-template>
		|      </xsl:when>
		|      <xsl:otherwise>
		|        <xsl:value-of select=""$str""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-trim-all"">
		|    <xsl:param name=""str"" />
		|      <xsl:call-template name=""str-trim-right"">
		|        <xsl:with-param name=""str"">
		|          <xsl:call-template name=""str-trim-left"">
		|            <xsl:with-param name=""str"" select=""$str""/>
		|          </xsl:call-template>
		|      </xsl:with-param>
		|    </xsl:call-template>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-replace-all"">
		|    <xsl:param name=""str"" />
		|    <xsl:param name=""search-for"" />
		|    <xsl:param name=""replace-by"" />
		|    <xsl:choose>
		|      <xsl:when test=""contains($str, $search-for)"">
		|        <xsl:value-of select=""substring-before($str, $search-for)"" />
		|        <xsl:value-of select=""$replace-by"" />
		|        <xsl:call-template name=""str-replace-all"">
		|          <xsl:with-param name=""str"" select=""substring-after($str, $search-for)"" />
		|          <xsl:with-param name=""search-for"" select=""$search-for"" />
		|          <xsl:with-param name=""replace-by"" select=""$replace-by"" />
		|        </xsl:call-template>
		|      </xsl:when>
		|      <xsl:otherwise>
		|        <xsl:value-of select=""$str"" />
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:param name=""alpha-low"" select=""'abcdefghijklmnopqrstuvwxyz'"" />
		|  <xsl:param name=""alpha-up""  select=""'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"" />
		|
		|  <xsl:template name=""str-upper"">
		|    <xsl:param name=""str"" />
		|    <xsl:value-of select=""translate($str, $alpha-low, $alpha-up)""/>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-lower"">
		|    <xsl:param name=""str"" />
		|    <xsl:value-of select=""translate($str, alpha-up, $alpha-low)"" />
		|  </xsl:template>
		|
		|<!-- /string functions -->
		|";
EndFunction

// XSL fragment with procedures for work with xpath.
//
// Returns:
//     String - XML fragment for using in conversion.
//
Function XSLT_XPathFunctionsTemplates()
	Return "
		|<!-- path functions -->
		|
		|  <xsl:template name=""build-path"">
		|  <xsl:variable name=""node"" select="".""/>
		|
		|    <xsl:for-each select=""$node | $node/ancestor-or-self::node()[..]"">
		|      <xsl:choose>
		|        <!-- element -->
		|        <xsl:when test=""self::*"">
		|            <xsl:value-of select=""'/'""/>
		|            <xsl:value-of select=""name()""/>
		|            <xsl:variable name=""thisPosition"" select=""count(preceding-sibling::*[name(current()) = name()])""/>
		|            <xsl:variable name=""numFollowing"" select=""count(following-sibling::*[name(current()) = name()])""/>
		|            <xsl:if test=""$thisPosition + $numFollowing > 0"">
		|              <xsl:value-of select=""concat('[', $thisPosition +1, ']')""/>
		|            </xsl:if>
		|        </xsl:when>
		|        <xsl:otherwise>
		|          <!-- not element -->
		|          <xsl:choose>
		|            <!-- attribute -->
		|            <xsl:when test=""count(. | ../@*) = count(../@*)"">
		|                <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""concat('@',name())""/>
		|            </xsl:when>
		|            <!-- text- -->
		|            <xsl:when test=""self::text()"">
		|                <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""'text()'""/>
		|                <xsl:variable name=""thisPosition"" select=""count(preceding-sibling::text())""/>
		|                <xsl:variable name=""numFollowing"" select=""count(following-sibling::text())""/>
		|                <xsl:if test=""$thisPosition + $numFollowing > 0""> 
		|                  <xsl:value-of select=""concat('[', $thisPosition +1, ']')""/>
		|                </xsl:if>
		|            </xsl:when>
		|            <!-- processing instruction -->
		|            <xsl:when test=""self::processing-instruction()"">
		|                <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""'processing-instruction()'""/>
		|                <xsl:variable name=""thisPosition"" select=""count(preceding-sibling::processing-instruction())""/>
		|                <xsl:variable name=""numFollowing"" select=""count(following-sibling::processing-instruction())""/>
		|                <xsl:if test=""$thisPosition + $numFollowing > 0"">
		|                  <xsl:value-of select=""concat('[', $thisPosition +1, ']')""/>
		|                </xsl:if>
		|            </xsl:when>
		|            <!-- comment -->
		|            <xsl:when test=""self::comment()"">
		|                <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""'comment()'""/>
		|                <xsl:variable name=""thisPosition"" select=""count(preceding-sibling::comment())""/>
		|                <xsl:variable name=""numFollowing"" select=""count(following-sibling::comment())""/>
		|                <xsl:if test=""$thisPosition + $numFollowing > 0"">
		|                  <xsl:value-of select=""concat('[', $thisPosition +1, ']')""/>
		|                </xsl:if>
		|            </xsl:when>
		|            <!-- namespace -->
		|            <xsl:when test=""count(. | ../namespace::*) = count(../namespace::*)"">
		|              <xsl:variable name=""ap"">'</xsl:variable>
		|              <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""concat('namespace::*','[local-name() = ', $ap, local-name(), $ap, ']')""/>
		|            </xsl:when>
		|          </xsl:choose>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:for-each>
		|
		|  </xsl:template>
		|
		|<!-- /path functions -->
		|";
EndFunction

#EndRegion
