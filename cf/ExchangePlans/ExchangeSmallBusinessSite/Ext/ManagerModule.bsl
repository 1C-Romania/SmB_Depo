#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Function ExchangePlanUsedSaaS() Export
	
	Return True;
	
EndFunction

//////////////////////////////////////////////////////////////////////////////
// FUNCTIONS FOR EXCHANGE THROUGH EXTERNAL CONNECTION

// Allows to predefine the exchange plan settings specified by default.
// For values of the default settings, see DataExchangeServer.DefaultExchangePlanSettings
// 
// Parameters:
// Settings - Structure - Contains default settings
//
// Example:
//	Settings.WarnAboutExchangeRulesVersionsMismatch = False;
Procedure DefineSettings(Settings) Export
	
	
	
EndProcedure // DefineSettings()

// Returns the filters structure on the exchange plan node of correspondent base with set default values;
// Structure of the settings repeats the content of header attributes and tabular sections of an exchange plan of a correspondent base;
// Structure items similar in key and value are used for
// header attributes. Structures containing arrays of
// tabular sections values of exchange plan parts are used for tabular sections.
// 
// Parameters:
//  No.
// 
// Returns:
//  SettingsStructure - Structure - structure of filters on the exchange plan node of a correspondent base
// 
Function CorrespondentInfobaseNodeFilterSetup() Export
	
	Return New Structure;
	
EndFunction

// Returns the default values structure for a correspondent base node;
// Settings structure repeats the attributes content of exchange plan header of a correspondent base;
// For the header attributes structure items similar by key and the structure item value are used.
// 
// Parameters:
//  No.
// 
// Returns:
//  SettingsStructure - Structure - structure of default values on the exchange plan node of a correspondent base
//
Function CorrespondentInfobaseNodeDefaultValues() Export
	
	Return New Structure;
	
EndFunction

// Returns a description string of migration restrictions of the data for a correspondent base that is displayed to the user;
// Application developer creates a user-friendly restrictions description string based on the set filters in the correspondent base node.
// 
// Parameters:
//  FilterSsettingsAtNode - Structure - structure of filters on the node
//                                       of the exchange plan of a correspondent base received using the FiltersSettingOnCorrespondentBaseNode() function.
// 
// Returns:
//  String, Unlimited. - String of restrictions description of the data migration for a user
//
Function CorrespondentInfobaseDataTransferRestrictionDetails(FilterSsettingsAtNode) Export
	
	Return "";
	
EndFunction

// Returns a string of default values description for a correspondent base that is displayed to a user;
// Application developer creates a user-friendly description string based on the default values in the correspondent base node.
// 
// Parameters:
//  DefaultValuesAtNode - Structure - structure of default values on the exchange plan
//                                       node of the correspondent base received using the DefaultValuesOnCorrespondentBaseNode() function.
// 
// Returns:
//  String, Unlimited. - description string for default values user
//
Function CorrespondentInfobaseDefaultValueDetails(DefaultValuesAtNode) Export
	
	Return "";
	
EndFunction

// Function returns the name of data export processor
//
Function DumpProcessingName() Export
	
	Return "";
	
EndFunction // ExportProcessorName()

// Function returns the name of data import processor
//
Function ImportProcessingName() Export
	
	Return "";
	
EndFunction // ImportProcessorName()

// Function should return:
// True if the correspondent supports the exchange scenario in which the current IB works in local mode, while correspondent works in service model. 
// 
// False - if such exchange scenario is not supported.
//
Function CorrespondentSaaS() Export
	
	Return False;
	
EndFunction // CorrespondentSaaS()

// Returns the name of configurations family. 
// Used to support exchanges with configurations changes in service.
//
Function SourceConfigurationName() Export
	
	Return "SmallBusiness";
	
EndFunction // SourceConfigurationName()

#EndIf