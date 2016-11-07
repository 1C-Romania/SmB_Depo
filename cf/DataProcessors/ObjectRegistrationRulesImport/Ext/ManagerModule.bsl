#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Initializes object registration rule table columns.
//
// Parameters:
//  No.
// 
Function ORRTableInitialization() Export
	
	ObjectRegistrationRules = New ValueTable;
	
	Columns = ObjectRegistrationRules.Columns;
	
	Columns.Add("SettingsObject");
	
	Columns.Add("MetadataObjectName", New TypeDescription("String"));
	Columns.Add("ExchangePlanName",      New TypeDescription("String"));
	
	Columns.Add("FlagAttributeName", New TypeDescription("String"));
	
	Columns.Add("QueryText",    New TypeDescription("String"));
	Columns.Add("PropertiesOfObject", New TypeDescription("Structure"));
	
	Columns.Add("ObjectPropertiesString", New TypeDescription("String"));
	
	// Shows that the rules are empty.
	Columns.Add("RuleByObjectPropertiesEmpty",     New TypeDescription("Boolean"));
	
	Columns.Add("FilterByExchangePlanProperties", New TypeDescription("ValueTree"));
	Columns.Add("FilterByObjectProperties",     New TypeDescription("ValueTree"));
	
	// events handlers
	Columns.Add("BeforeProcess",            New TypeDescription("String"));
	Columns.Add("OnProcess",                New TypeDescription("String"));
	Columns.Add("OnProcessAdditional",      New TypeDescription("String"));
	Columns.Add("AfterProcessing",          New TypeDescription("String"));
	
	Columns.Add("HasBeforeProcessHandler",           New TypeDescription("Boolean"));
	Columns.Add("HasOnProcessHandler",               New TypeDescription("Boolean"));
	Columns.Add("HasOnProcessHandlerAdditional",     New TypeDescription("Boolean"));
	Columns.Add("HasAfterProcessHandler",            New TypeDescription("Boolean"));
	
	Return ObjectRegistrationRules;
	
EndFunction

// Initializes registration rule table columns according to properties.
//
// Parameters:
//  No.
// 
Function FilterByExchangePlanPropertiesTableInitialization() Export
	
	TreePattern = New ValueTree;
	
	Columns = TreePattern.Columns;
	
	Columns.Add("IsFolder",            New TypeDescription("Boolean"));
	Columns.Add("BooleanGroupValue",   New TypeDescription("String"));
	
	Columns.Add("ObjectProperty",      New TypeDescription("String"));
	Columns.Add("ComparisonType",      New TypeDescription("String"));
	Columns.Add("IsConstantString",    New TypeDescription("Boolean"));
	Columns.Add("ObjectPropertyType",  New TypeDescription("String"));
	
	Columns.Add("NodeParameter",                New TypeDescription("String"));
	Columns.Add("NodeParameterTabularSection", New TypeDescription("String"));
	
	Columns.Add("ConstantValue"); // arbitrary type
	
	Return TreePattern;
	
EndFunction

// Initializes registration rule table columns according to properties.
//
// Parameters:
//  No.
// 
Function FilterByObjectPropertiesTableInitialization() Export
	
	TreePattern = New ValueTree;
	
	Columns = TreePattern.Columns;
	
	Columns.Add("IsFolder",           New TypeDescription("Boolean"));
	Columns.Add("IsAndOperator",      New TypeDescription("Boolean"));
	
	Columns.Add("ObjectProperty",     New TypeDescription("String"));
	Columns.Add("ObjectPropertyKey",  New TypeDescription("String"));
	Columns.Add("ComparisonType",     New TypeDescription("String"));
	Columns.Add("ObjectPropertyType", New TypeDescription("String"));
	Columns.Add("FilterItemKind",     New TypeDescription("String"));
	
	Columns.Add("ConstantValue"); // arbitrary type
	Columns.Add("PropertyValue");  // arbitrary type
	
	Return TreePattern;
	
EndFunction

#EndRegion

#EndIf