#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var Registration Export; // Structure containing registration parameters.
Var ObjectRegistrationRules Export; // Values table with objects registration rules.
Var ErrorFlag Export; // error global check box

Var StringType;
Var BooleanType;
Var NumberType;
Var DateType;

Var EmptyDateValue;
Var FilterByExchangePlanPropertiesTreePattern;  // Values tree template for registration rules by
                                                // Exchange plan properties.
Var FilterByObjectPropertiesTreePattern;      // Values tree template for registration rules by Object properties.
Var BooleanPropertyRootGroupValue; // Boolean value for a root properties group.
Var ErrorMessages; // Matching. Key - error code, Value - error description.

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// Executes syntax analysis of XML-file with registration rules. Fills in collection values by the file data;
// Prepares read rules for ORR (rules "compilation").
//
// Parameters:
//  FileName         - String - file full name containing rules in the local file system.
//  InfoOnly - Boolean - shows that it is required to read only file title and rules information;
//                              (value by default - False).
//
Procedure ImportRules(Val FileName, InfoOnly = False) Export
	
	ErrorFlag = False;
	
	If IsBlankString(FileName) Then
		MessageAboutProcessingError(4);
		Return;
	EndIf;
	
	// Initialize collections for rules.
	Registration                             = RegistrationInitialization();
	ObjectRegistrationRules              = DataProcessors.ObjectRegistrationRulesImport.ORRTableInitialization();
	FilterByExchangePlanPropertiesTreePattern = DataProcessors.ObjectRegistrationRulesImport.FilterByExchangePlanPropertiesTableInitialization();
	FilterByObjectPropertiesTreePattern     = DataProcessors.ObjectRegistrationRulesImport.FilterByObjectPropertiesTableInitialization();
	
	// UPLOAD REGISTRATION RULES
	Try
		ImportRegistrationFromFile(FileName, InfoOnly);
	Except
		
		// write error
		MessageAboutProcessingError(2, BriefErrorDescription(ErrorInfo()));
		
	EndTry;
	
	// Exit if rules reading from file is complete with errors.
	If ErrorFlag Then
		Return;
	EndIf;
	
	If InfoOnly Then
		Return;
	EndIf;
	
	// PREPARE RULES FOR ORR PLAYER
	
	For Each ORR IN ObjectRegistrationRules Do
		
		PrepareRegistrationRuleByExchangePlanProperties(ORR);
		
		PrepareRegistrationRuleByObjectProperties(ORR);
		
	EndDo;
	
	ObjectRegistrationRules.FillValues(Registration.ExchangePlanName, "ExchangePlanName");
	
EndProcedure

// Prepares string with information about the rules based on the data read from XML-file.
// 
// Parameters:
//  No.
// 
// Returns:
//  InfoString - String - String with rules information.
//
Function GetInformationAboutRules() Export
	
	// Return value of the function.
	InfoString = "";
	
	If ErrorFlag Then
		Return InfoString;
	EndIf;
	
	InfoString = NStr("en='Registration rules of this infobase objects (%1) from %2';ru='Правила регистрации объектов этой информационной базы (%1) от %2'");
	
	Return StringFunctionsClientServer.PlaceParametersIntoString(InfoString,
					GetConfigurationPresentationFromRegistrationRules(),
					Format(Registration.CreationDateTime, "DLF = dd"));
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Import object registration rules (ORR).

Procedure ImportRegistrationFromFile(FileName, InfoOnly)
	
	// open file for reading
	Try
		Rules = New XMLReader();
		Rules.OpenFile(FileName);
		Rules.Read();
	Except
		Rules = Undefined;
		MessageAboutProcessingError(1, BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	Try
		ImportRegistration(Rules, InfoOnly);
	Except
		MessageAboutProcessingError(2, BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Rules.Close();
	Rules = Undefined;
	
EndProcedure

// Imports registration rules according to the format.
//
// Parameters:
//  
Procedure ImportRegistration(Rules, InfoOnly)
	
	If Not ((Rules.LocalName = "RegistrationRules") 
		AND (Rules.NodeType = XMLNodeType.StartElement)) Then
		
		// Rules format error
		MessageAboutProcessingError(3);
		
		Return;
		
	EndIf;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		// Registration attributes
		If NodeName = "FormatVersion" Then
			
			Registration.FormatVersion = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "ID" Then
			
			Registration.ID = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "Description" Then
			
			Registration.Description = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "CreationDateTime" Then
			
			Registration.CreationDateTime = deItemValue(Rules, DateType);
			
		ElsIf NodeName = "ExchangePlan" Then
			
			// attributes for exchange plan
			Registration.ExchangePlanName = deAttribute(Rules, StringType, "Name");
			
			Registration.ExchangePlan = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "Comment" Then
			
			Registration.Comment = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "Configuration" Then
			
			// configuration attributes
			Registration.PlatformVersion     = deAttribute(Rules, StringType, "PlatformVersion");
			Registration.ConfigurationVersion  = deAttribute(Rules, StringType, "ConfigurationVersion");
			Registration.ConfigurationSynonym = deAttribute(Rules, StringType, "ConfigurationSynonym");
			
			// configuration name
			Registration.Configuration = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "ObjectRegistrationRules" Then
			
			If InfoOnly Then
				
				Break; // Exit; if it is required to import only information about registration.
				
			Else
				
				// Check ORR import for the required exchange plan.
				RunExchangePlanPresenceCheckup();
				
				If ErrorFlag Then
					Break; // Exit; do not import if the wrong exchange plan is specified in the rules.
				EndIf;
				
				ImportRegistrationRules(Rules);
				
			EndIf;
			
		ElsIf (NodeName = "RegistrationRules") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deIgnore(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports registration rules according to the exchange rules format.
//
// Parameters:
//  Rules - Object of the XMLReading type.
// 
Procedure ImportRegistrationRules(Rules)
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		
		If NodeName = "Rule" Then
			
			ImportRegistrationRule(Rules);
			
		ElsIf NodeName = "Group" Then
			
			ImportRegistrationRulesGroup(Rules);
			
		ElsIf (NodeName = "ObjectRegistrationRules") AND (Rules.NodeType = XMLNodeType.EndElement) Then
			
			Break;
			
		Else
			
			deIgnore(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports objects registration rule.
//
// Parameters:
//  Rules  - Object of the XMLReading type.
// 
Procedure ImportRegistrationRule(Rules)
	
	// Do not import rules with the specified flag "Disable".
	Disable = deAttribute(Rules, BooleanType, "Disable");
	If Disable Then
		deIgnore(Rules);
		Return;
	EndIf;
	
	// Do not import rules with errors.
	Valid = deAttribute(Rules, BooleanType, "Valid");
	If Not Valid Then
		deIgnore(Rules);
		Return;
	EndIf;
	
	NewRow = ObjectRegistrationRules.Add();
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		
		If NodeName = "SettingsObject" Then
			
			NewRow.SettingsObject = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "MetadataObjectName" Then
			
			NewRow.MetadataObjectName = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "ExportModeAttribute" Then
			
			NewRow.FlagAttributeName = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "FilterByExchangePlanProperties" Then
			
			// Initialize properties collection for the current ORR.
			NewRow.FilterByExchangePlanProperties = FilterByExchangePlanPropertiesTreePattern.Copy();
			
			ImportFilterTreeByExchangePlanProperties(Rules, NewRow.FilterByExchangePlanProperties);
			
		ElsIf NodeName = "FilterByObjectProperties" Then
			
			// Initialize properties collection for the current ORR.
			NewRow.FilterByObjectProperties = FilterByObjectPropertiesTreePattern.Copy();
			
			ImportFilterTreeByObjectProperties(Rules, NewRow.FilterByObjectProperties);
			
		ElsIf NodeName = "BeforeProcess" Then
			
			NewRow.BeforeProcess = deItemValue(Rules, StringType);
			
			NewRow.HasBeforeProcessHandler = Not IsBlankString(NewRow.BeforeProcess);
			
		ElsIf NodeName = "OnProcess" Then
			
			NewRow.OnProcess = deItemValue(Rules, StringType);
			
			NewRow.HasOnProcessHandler = Not IsBlankString(NewRow.OnProcess);
			
		ElsIf NodeName = "OnProcessAdditional" Then
			
			NewRow.OnProcessAdditional = deItemValue(Rules, StringType);
			
			NewRow.HasOnProcessHandlerAdditional = Not IsBlankString(NewRow.OnProcessAdditional);
			
		ElsIf NodeName = "AfterProcessing" Then
			
			NewRow.AfterProcessing = deItemValue(Rules, StringType);
			
			NewRow.HasAfterProcessHandler = Not IsBlankString(NewRow.AfterProcessing);
			
		ElsIf (NodeName = "Rule") AND (Rules.NodeType = XMLNodeType.EndElement) Then
			
			Break;
			
		Else
			
			deIgnore(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ImportFilterTreeByExchangePlanProperties(Rules, ValueTree)
	
	VTRows = ValueTree.Rows;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterItem" Then
			
			ImportExchangePlanFilterElement(Rules, VTRows.Add());
			
		ElsIf NodeName = "Group" Then
			
			ImportExchangePlanFilterElementsGroup(Rules, VTRows.Add());
			
		ElsIf (NodeName = "FilterByExchangePlanProperties") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deIgnore(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ImportFilterTreeByObjectProperties(Rules, ValueTree)
	
	VTRows = ValueTree.Rows;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterItem" Then
			
			ImportObjectFilterElement(Rules, VTRows.Add());
			
		ElsIf NodeName = "Group" Then
			
			ImportObjectFilterElementsGroup(Rules, VTRows.Add());
			
		ElsIf (NodeName = "FilterByObjectProperties") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deIgnore(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports object registration rule by property.
//
// Parameters:
// 
Procedure ImportExchangePlanFilterElement(Rules, NewRow)
	
	NewRow.IsFolder = False;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "ObjectProperty" Then
			
			If NewRow.IsConstantString Then
				
				NewRow.ConstantValue = deItemValue(Rules, Type(NewRow.ObjectPropertyType));
				
			Else
				
				NewRow.ObjectProperty = deItemValue(Rules, StringType);
				
			EndIf;
			
		ElsIf NodeName = "ExchangePlanProperty" Then
			
			// Property can be header property or
			// TS property if this is TS
			// property, then the PropertyFullName variable contains TS name and property name.
			// TS name is written in brackets "[...]".
			// For example, "[Company].Company"
			PropertyFullDescr = deItemValue(Rules, StringType);
			
			ExchangePlanTabularSectionName = "";
			
			FirstBracketPosition = Find(PropertyFullDescr, "[");
			
			If FirstBracketPosition <> 0 Then
				
				SecondBracketPosition = Find(PropertyFullDescr, "]");
				
				ExchangePlanTabularSectionName = Mid(PropertyFullDescr, FirstBracketPosition + 1, SecondBracketPosition - FirstBracketPosition - 1);
				
				PropertyFullDescr = Mid(PropertyFullDescr, SecondBracketPosition + 2);
				
			EndIf;
			
			NewRow.NodeParameter                = PropertyFullDescr;
			NewRow.NodeParameterTabularSection = ExchangePlanTabularSectionName;
			
		ElsIf NodeName = "ComparisonType" Then
			
			NewRow.ComparisonType = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "IsConstantString" Then
			
			NewRow.IsConstantString = deItemValue(Rules, BooleanType);
			
		ElsIf NodeName = "ObjectPropertyType" Then
			
			NewRow.ObjectPropertyType = deItemValue(Rules, StringType);
			
		ElsIf (NodeName = "FilterItem") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deIgnore(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports object registration rule by property.
//
// Parameters:
// 
Procedure ImportObjectFilterElement(Rules, NewRow)
	
	NewRow.IsFolder = False;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "ObjectProperty" Then
			
			NewRow.ObjectProperty = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "ConstantValue" Then
			
			If IsBlankString(NewRow.FilterItemKind) Then
				
				NewRow.FilterItemKind = DataExchangeServer.FilterItemPropertyConstantValue();
				
			EndIf;
			
			If NewRow.FilterItemKind = DataExchangeServer.FilterItemPropertyConstantValue() Then
				
				// only primitive types
				NewRow.ConstantValue = deItemValue(Rules, Type(NewRow.ObjectPropertyType));
				
			ElsIf NewRow.FilterItemKind = DataExchangeServer.FilterItemPropertyValueAlgorithm() Then
				
				NewRow.ConstantValue = deItemValue(Rules, StringType); // string
				
			Else
				
				NewRow.ConstantValue = deItemValue(Rules, StringType); // string
				
			EndIf;
			
		ElsIf NodeName = "ComparisonType" Then
			
			NewRow.ComparisonType = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "ObjectPropertyType" Then
			
			NewRow.ObjectPropertyType = deItemValue(Rules, StringType);
			
		ElsIf NodeName = "Kind" Then
			
			NewRow.FilterItemKind = deItemValue(Rules, StringType);
			
		ElsIf (NodeName = "FilterItem") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deIgnore(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports object registration rules group by property.
//
// Parameters:
//  Rules  - Object of the XMLReading type.
// 
Procedure ImportExchangePlanFilterElementsGroup(Rules, NewRow)
	
	NewRow.IsFolder = True;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterItem" Then
			
			ImportExchangePlanFilterElement(Rules, NewRow.Rows.Add());
		
		ElsIf (NodeName = "Group") AND (NodeType = XMLNodeType.StartElement) Then
			
			ImportExchangePlanFilterElementsGroup(Rules, NewRow.Rows.Add());
			
		ElsIf NodeName = "BooleanGroupValue" Then
			
			NewRow.BooleanGroupValue = deItemValue(Rules, StringType);
			
		ElsIf (NodeName = "Group") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deIgnore(Rules);
			
		EndIf;
		
	EndDo;

EndProcedure

// Imports object registration rules group by property.
//
// Parameters:
//  Rules  - Object of the XMLReading type.
// 
Procedure ImportObjectFilterElementsGroup(Rules, NewRow)
	
	NewRow.IsFolder = True;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterItem" Then
			
			ImportObjectFilterElement(Rules, NewRow.Rows.Add());
		
		ElsIf (NodeName = "Group") AND (NodeType = XMLNodeType.StartElement) Then
			
			ImportObjectFilterElementsGroup(Rules, NewRow.Rows.Add());
			
		ElsIf NodeName = "BooleanGroupValue" Then
			
			BooleanGroupValue = deItemValue(Rules, StringType);
			
			NewRow.IsAndOperator = (BooleanGroupValue = "AND");
			
		ElsIf (NodeName = "Group") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit
			
		Else
			
			deIgnore(Rules);
			
		EndIf;
		
	EndDo;

EndProcedure

Procedure ImportRegistrationRulesGroup(Rules)
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		
		If NodeName = "Rule" Then
			
			ImportRegistrationRule(Rules);
			
		ElsIf NodeName = "Group" AND Rules.NodeType = XMLNodeType.StartElement Then
			
			ImportRegistrationRulesGroup(Rules);
			
		ElsIf NodeName = "Group" AND Rules.NodeType = XMLNodeType.EndElement Then
		
			Break;
			
		Else
			
			deIgnore(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Objects registration rules (ORR) compilation by Exchange plan properties.

Procedure PrepareRegistrationRuleByExchangePlanProperties(ORR)
	
	EmptyRule = (ORR.FilterByExchangePlanProperties.Rows.Count() = 0);
	
	PropertiesOfObject = New Structure;
	
	FieldSelectionText = "SELECT DISTINCT ExchangePlanMainTable.Ref AS Ref";
	
	// Table with the data source names - exchange plan tabular sections.
	DataTable = GetDataTableForORR(ORR.FilterByExchangePlanProperties.Rows);
	
	TableDataText = GetDataTableTextForORR(DataTable);
	
	If EmptyRule Then
		
		ConditionText = "True";
		
	Else
		
		ConditionText = GetConditionTextForGroupOfProperties(ORR.FilterByExchangePlanProperties.Rows, BooleanPropertyRootGroupValue, 0, PropertiesOfObject);
		
	EndIf;
	
	QueryText = FieldSelectionText + Chars.LF 
	             + "IN"  + Chars.LF + TableDataText + Chars.LF
	             + "WHERE" + Chars.LF + ConditionText
	             + Chars.LF + "[MandatoryConditions]";
	//
	
	// Assign received variable values.
	ORR.QueryText    = QueryText;
	ORR.PropertiesOfObject = PropertiesOfObject;
	ORR.ObjectPropertiesString = GetObjectPropertiesAsString(PropertiesOfObject);
	
EndProcedure

Function GetConditionTextForGroupOfProperties(GroupProperties, BooleanGroupValue, Val Shift, PropertiesOfObject)
	
	OffsetString = "";
	
	// Receive shift string for properties group.
	For A = 0 To Shift Do
		OffsetString = OffsetString + " ";
	EndDo;
	
	ConditionText = "";
	
	For Each RecordRuleByProperty IN GroupProperties Do
		
		If RecordRuleByProperty.IsFolder Then
			
			ConditionPrefix = ?(IsBlankString(ConditionText), "", Chars.LF + OffsetString + BooleanGroupValue + " ");
			
			ConditionText = ConditionText + ConditionPrefix + GetConditionTextForGroupOfProperties(RecordRuleByProperty.Rows, RecordRuleByProperty.BooleanGroupValue, Shift + 10, PropertiesOfObject);
			
		Else
			
			ConditionPrefix = ?(IsBlankString(ConditionText), "", Chars.LF + OffsetString + BooleanGroupValue + " ");
			
			ConditionText = ConditionText + ConditionPrefix + GetConditionTextForProperty(RecordRuleByProperty, PropertiesOfObject);
			
		EndIf;
		
	EndDo;
	
	ConditionText = "(" + ConditionText + Chars.LF 
				 + OffsetString + ")";
	
	Return ConditionText;
	
EndFunction

Function GetDataTableTextForORR(DataTable)
	
	TableDataText = "ExchangePlan." + Registration.ExchangePlanName + " AS ExchangePlanMainTable";
	
	For Each TableRow IN DataTable Do
		
		TableSynonym = Registration.ExchangePlanName + TableRow.Name;
		
		TableDataText = TableDataText + Chars.LF + Chars.LF + "LEFT JOIN" + Chars.LF
		                 + "ExchangePlan." + Registration.ExchangePlanName + "." + TableRow.Name + " AS " + TableSynonym + "" + Chars.LF
		                 + "BY ExchangePlanMainTable.Ref = " + TableSynonym + ".Ref";
		
	EndDo;
	
	Return TableDataText;
	
EndFunction

Function GetDataTableForORR(GroupProperties)
	
	DataTable = New ValueTable;
	DataTable.Columns.Add("Name");
	
	For Each RecordRuleByProperty IN GroupProperties Do
		
		If RecordRuleByProperty.IsFolder Then
			
			// Receive data table for the low hierarchy level.
			GroupDataTable = GetDataTableForORR(RecordRuleByProperty.Rows);
			
			// Add received rows to the table of the hierarchy top level data.
			For Each GroupTableRow IN GroupDataTable Do
				
				FillPropertyValues(DataTable.Add(), GroupTableRow);
				
			EndDo;
			
		Else
			
			TableName = RecordRuleByProperty.NodeParameterTabularSection;
			
			// If a table name is empty, then this is a property of the node header; ignore.
			If Not IsBlankString(TableName) Then
				
				TableRow = DataTable.Add();
				TableRow.Name = TableName;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// collapse table
	DataTable.GroupBy("Name");
	
	Return DataTable;
	
EndFunction

Function GetConditionTextForProperty(Rule, PropertiesOfObject)
	
	Var ComparisonType;
	
	ComparisonType = Rule.ComparisonType;
	
	// It is required
	// to invert comparison kind as the tables of Exchange plan and
	// registered Object are located differently in CD 2 configuration.0 while setting ORR and in the query to Exchange plan in this module.
	InvertComparisonType(ComparisonType);
	
	TextOperator = GetCompareOperatorText(ComparisonType);
	
	TableSynonym = ?(IsBlankString(Rule.NodeParameterTabularSection),
	                              "ExchangePlanMainTable",
	                               Registration.ExchangePlanName + Rule.NodeParameterTabularSection);
	//
	
	// As a literal query parameter, either a query parameter or a constant value can be used.
	//
	// Example:
	// ExchangePlanProperty
	// <comparison kind> &ObjectProperty_MyProperty ExchangePlanProperty <comparison kind> DATETIME(1987,10,19,0,0,0)
	
	If Rule.IsConstantString Then
		
		ConstantValueType = TypeOf(Rule.ConstantValue);
		
		If ConstantValueType = BooleanType Then // Boolean
			
			QueryParameterLiteral = Format(Rule.ConstantValue, "BF=False; BT=True");
			
		ElsIf ConstantValueType = NumberType Then // Number
			
			QueryParameterLiteral = Format(Rule.ConstantValue, "NDS=.; NZ=0; NG=0; NN=1");
			
		ElsIf ConstantValueType = DateType Then // Date
			
			YearString     = Format(Year(Rule.ConstantValue),     "NZ=0; NG=0");
			MonthString   = Format(Month(Rule.ConstantValue),   "NZ=0; NG=0");
			DayString    = Format(Day(Rule.ConstantValue),    "NZ=0; NG=0");
			HourString     = Format(Hour(Rule.ConstantValue),     "NZ=0; NG=0");
			MinuteString  = Format(Minute(Rule.ConstantValue),  "NZ=0; NG=0");
			SecondString = Format(Second(Rule.ConstantValue), "NZ=0; NG=0");
			
			QueryParameterLiteral = "DATETIME("
			+ YearString + ","
			+ MonthString + ","
			+ DayString + ","
			+ HourString + ","
			+ MinuteString + ","
			+ SecondString
			+ ")";
			
		Else // String
			
			// put a string in quotation marks
			QueryParameterLiteral = """" + Rule.ConstantValue + """";
			
		EndIf;
		
	Else
		
		ObjectPropertyKey = StrReplace(Rule.ObjectProperty, ".", "_");
		
		QueryParameterLiteral = "&ObjectProperty_" + ObjectPropertyKey + "";
		
		PropertiesOfObject.Insert(ObjectPropertyKey, Rule.ObjectProperty);
		
	EndIf;
	
	ConditionText = TableSynonym + "." + Rule.NodeParameter + " " + TextOperator + " " + QueryParameterLiteral;
	
	Return ConditionText;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Compilation of objects registration rules (ORR) by the Object properties.

Procedure PrepareRegistrationRuleByObjectProperties(ORR)
	
	ORR.RuleByObjectPropertiesEmpty = (ORR.FilterByObjectProperties.Rows.Count() = 0);
	
	// Do not process an empty rule.
	If ORR.RuleByObjectPropertiesEmpty Then
		Return;
	EndIf;
	
	PropertiesOfObject = New Structure;
	
	FillObjectPropertiesStructure(ORR.FilterByObjectProperties, PropertiesOfObject);
	
EndProcedure

Procedure FillObjectPropertiesStructure(ValueTree, PropertiesOfObject)
	
	For Each TreeRow IN ValueTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			FillObjectPropertiesStructure(TreeRow, PropertiesOfObject);
			
		Else
			
			TreeRow.ObjectPropertyKey = StrReplace(TreeRow.ObjectProperty, ".", "_");
			
			PropertiesOfObject.Insert(TreeRow.ObjectPropertyKey, TreeRow.ObjectProperty);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper service procedures and functions.

Procedure MessageAboutProcessingError(Code = -1, ErrorDescription = "")
	
	// Select error global check box.
	ErrorFlag = True;
	
	If ErrorMessages = Undefined Then
		ErrorMessages = MessagesInitialization();
	EndIf;
	
	MessageString = ErrorMessages[Code];
	
	MessageString = ?(MessageString = Undefined, "", MessageString);
	
	If Not IsBlankString(ErrorDescription) Then
		
		MessageString = MessageString + Chars.LF + ErrorDescription;
		
	EndIf;
	
	WriteLogEvent(EventLogMonitorMessageKey(), EventLogLevel.Error,,, MessageString);
	
EndProcedure

Procedure InvertComparisonType(ComparisonType)
	
	If      ComparisonType = "Greater"         Then ComparisonType = "Less";
	ElsIf ComparisonType = "GreaterOrEqual" Then ComparisonType = "LessOrEqual";
	ElsIf ComparisonType = "Less"         Then ComparisonType = "Greater";
	ElsIf ComparisonType = "LessOrEqual" Then ComparisonType = "GreaterOrEqual";
	EndIf;
	
EndProcedure

Procedure RunExchangePlanPresenceCheckup()
	
	If TypeOf(Registration) <> Type("Structure") Then
		
		MessageAboutProcessingError(0);
		Return;
		
	EndIf;
	
	If Registration.ExchangePlanName <> ExchangePlanImportName Then
		
		ErrorDescription = NStr("en='In the registration rules the %1 exchange plan is specified but the import is performed for the %2 exchange plan.';ru='В правилах регистрации указан план обмена %1, а загрузка выполняется для плана обмена %2'");
		ErrorDescription = StringFunctionsClientServer.PlaceParametersIntoString(ErrorDescription, Registration.ExchangePlanName, ExchangePlanImportName);
		MessageAboutProcessingError(5, ErrorDescription);
		
	EndIf;
	
EndProcedure

Function GetCompareOperatorText(Val ComparisonType = "Equal")
	
	// Default return value of the function.
	TextOperator = "=";
	
	If      ComparisonType = "Equal"          Then TextOperator = "=";
	ElsIf ComparisonType = "NotEqual"        Then TextOperator = "<>";
	ElsIf ComparisonType = "Greater"         Then TextOperator = ">";
	ElsIf ComparisonType = "GreaterOrEqual" Then TextOperator = ">=";
	ElsIf ComparisonType = "Less"         Then TextOperator = "<";
	ElsIf ComparisonType = "LessOrEqual" Then TextOperator = "<=";
	EndIf;
	
	Return TextOperator;
EndFunction

Function GetConfigurationPresentationFromRegistrationRules()
	
	ConfigurationName = "";
	Registration.Property("ConfigurationSynonym", ConfigurationName);
	
	If Not ValueIsFilled(ConfigurationName) Then
		Return "";
	EndIf;
	
	AccurateVersion = "";
	Registration.Property("ConfigurationVersion", AccurateVersion);
	
	If ValueIsFilled(AccurateVersion) Then
		
		AccurateVersion = CommonUseClientServer.ConfigurationVersionWithoutAssemblyNumber(AccurateVersion);
		
		ConfigurationName = ConfigurationName + " version " + AccurateVersion;
		
	EndIf;
	
	Return ConfigurationName;
		
EndFunction

Function GetObjectPropertiesAsString(PropertiesOfObject)
	
	Result = "";
	
	For Each Item IN PropertiesOfObject Do
		
		Result = Result + Item.Value + " AS " + Item.Key + ", ";
		
	EndDo;
	
	// Delete two last characters.
	StringFunctionsClientServer.DeleteLatestCharInRow(Result, 2);
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// For work with the XMLReading object.

// Reads attribute value by the name of the specified
// object, brings the value to the specified primitive type.
//
// Parameters:
//  Object      - XMLReading type object positioned on
//                the item start attribute of which is required to be received.
//  Type         - Value of the Type type. Attribute type.
//  Name         - String. Attribute name.
//
// Returns:
//  Attribute value received by the name and subjected to the specified type.
// 
Function deAttribute(Object, Type, Name)
	
	ValueStr = TrimR(Object.GetAttribute(Name));
	
	If Not IsBlankString(ValueStr) Then
		
		Return XMLValue(Type, ValueStr);
		
	Else
		If Type = StringType Then
			Return "";
			
		ElsIf Type = BooleanType Then
			Return False;
			
		ElsIf Type = NumberType Then
			Return 0;
			
		ElsIf Type = DateType Then
			Return EmptyDateValue;
			
		EndIf;
	EndIf;
	
EndFunction

// Reads item text and reduces value to the specified type.
//
// Parameters:
//  Object           - object of the XMLReading type from which reading is executed.
//  Type              - received value type.
//  SearchByProperty - for reference types a property can be specified
//                     according to which you should search for an object: "Code", "Name", <AttributeName>, "Name" (predefined value).
//
// Returns:
//  Xml-item value reduced to the corresponding type.
//
Function deItemValue(Object, Type, SearchByProperty="")

	Value = "";
	Name      = Object.LocalName;

	While Object.Read() Do
		
		NodeName = Object.LocalName;
		NodeType = Object.NodeType;
		
		If NodeType = XMLNodeType.Text Then
			
			Value = TrimR(Object.Value);
			
		ElsIf (NodeName = Name) AND (NodeType = XMLNodeType.EndElement) Then
			
			Break;
			
		Else
			
			Return Undefined;
			
		EndIf;
	EndDo;
	
	Return XMLValue(Type, Value)
	
EndFunction

// Skips xml nodes up to the end of the current item (current by default).
//
// Parameters:
//  Object   - object of the XMLReading type.
//  Name      - node name up to the end of which you should skip items.
// 
Procedure deIgnore(Object, Name = "")
	
	AttachmentsQuantity = 0; // Eponymous attachments quantity.
	
	If IsBlankString(Name) Then
	
		Name = Object.LocalName;
	
	EndIf;
	
	While Object.Read() Do
		
		NodeName = Object.LocalName;
		NodeType = Object.NodeType;
		
		If NodeName = Name Then
			
			If NodeType = XMLNodeType.EndElement Then
				
				If AttachmentsQuantity = 0 Then
					Break;
				Else
					AttachmentsQuantity = AttachmentsQuantity - 1;
				EndIf;
				
			ElsIf NodeType = XMLNodeType.StartElement Then
				
				AttachmentsQuantity = AttachmentsQuantity + 1;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local service functions-properties.

Function EventLogMonitorMessageKey()
	
	Return DataExchangeServer.DataExchangeRuleImportingEventLogMonitorMessageText();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Initialize attributes and module variables.

// Initializes data processor attributes and module variables.
//
// Parameters:
//  No.
// 
Procedure AttributesAndModuleVariablesInitialization()
	
	ErrorFlag = False;
	
	// Types
	StringType            = Type("String");
	BooleanType            = Type("Boolean");
	NumberType             = Type("Number");
	DateType              = Type("Date");
	
	EmptyDateValue = Date('00010101');
	
	BooleanPropertyRootGroupValue = "AND"; // Boolean value for a root properties group.
	
EndProcedure

// Initializes registration structure.
//
// Parameters:
//  No.
// 
Function RegistrationInitialization()
	
	Registration = New Structure;
	Registration.Insert("FormatVersion",       "");
	Registration.Insert("ID",                  "");
	Registration.Insert("Description",        "");
	Registration.Insert("CreationDateTime",   EmptyDateValue);
	Registration.Insert("ExchangePlan",          "");
	Registration.Insert("ExchangePlanName",      "");
	Registration.Insert("Comment",         "");
	
	// configuration parameters
	Registration.Insert("PlatformVersion",     "");
	Registration.Insert("ConfigurationVersion",  "");
	Registration.Insert("ConfigurationSynonym", "");
	Registration.Insert("Configuration",        "");
	
	Return Registration;
	
EndFunction

// Initialize variable containing messages codes match to their descriptions.
//
// Parameters:
//  No.
// 
Function MessagesInitialization()
	
	Messages = New Map;
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Messages.Insert(0, NStr("en='Internal error';ru='Внутренняя ошибка'", MainLanguageCode));
	Messages.Insert(1, NStr("en='File rules opening error';ru='Ошибка открытия файла правил'", MainLanguageCode));
	Messages.Insert(2, NStr("en='Error loading rules';ru='Ошибка при загрузке правил'", MainLanguageCode));
	Messages.Insert(3, NStr("en='Rules format error';ru='Ошибка формата правил'", MainLanguageCode));
	Messages.Insert(4, NStr("en='Error when receiving the file of rules for reading';ru='Ошибка при получении файла правил для чтения'", MainLanguageCode));
	Messages.Insert(5, NStr("en='The imported registration rules are not intended for the current exchange plan.';ru='Загружаемые правила регистрации не предназначены для текущего плана обмена.'", MainLanguageCode));
	
	Return Messages;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Operators of the main application.

AttributesAndModuleVariablesInitialization();

#EndRegion

#EndIf