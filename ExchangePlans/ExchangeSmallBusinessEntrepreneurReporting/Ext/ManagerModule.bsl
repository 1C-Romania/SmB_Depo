#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Allows to predefine the exchange plan settings specified by default.
// For values of the default settings, see DataExchangeServer.DefaultExchangePlanSettings
// 
// Parameters:
// Settings - Structure - Contains default settings
//
// Example:
//	Settings.WarnAboutExchangeRulesVersionsMismatch = False;
Procedure DefineSettings(Settings, SettingID) Export
	
	
	
EndProcedure // DefineSettings()

// Returns the settings attachment file name by default;
// the settings of an exchange for a receiver will be exported to this file;
// This value must be the same in the source exchange plan and receiver.
// 
// Parameters:
//  No.
// 
// Returns:
//  String, 255 - name of the default file for export settings of the data exchange
//
Function SettingsFilenameForReceiver() Export
	
	Return "Exchange settings for SB-OP";
	
EndFunction

// Returns the filters structure on the exchange plan node with the set default values;
// Settings structure repeats the attributes content of header and exchange plan tabular sections;
// Structure items similar in key and value are used for
// header attributes. Structures containing arrays of
// tabular sections values of exchange plan parts are used for tabular sections.
// 
// Parameters:
//  No.
// 
// Returns:
//  SettingsStructure - Structure - structure of filters on the exchange plan node
// 
Function FilterSsettingsAtNode(CorrespondentVersion, FormName, SettingID) Export
	
	CounterpartyTabularSectionStructure = New Structure;
	CounterpartyTabularSectionStructure.Insert("Company", New Array);
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("DocumentsDumpStartDate",    BegOfYear(CurrentDate()));
	SettingsStructure.Insert("UseCompaniesFilter", False);
	SettingsStructure.Insert("Companies",                     CounterpartyTabularSectionStructure);
	
	Return SettingsStructure;
	
EndFunction

// Returns the default values structure for a node;
// Structure of the settings repeats the content of exchange plan header attributes;
// For the header attributes structure items similar by key and the structure item value are used.
// 
// Parameters:
//  No.
// 
// Returns:
//  SettingsStructure - Structure - structure of default values on the exchange plan node
// 
Function DefaultValuesAtNode(CorrespondentVersion, FormName, SettingID) Export
	
	Return Undefined;
	
EndFunction

// Returns a row of restrictions description of the migration data for a user;
// Applied developer based on set filters on the node should generate a row of restrictions description convenient for a user.
// 
// Parameters:
//  FilterSsettingsAtNode - Structure - structure of filters on
//                                       node of an exchange plan received using the FiltersSettingsOnNode() function.
// 
// Returns:
//  String, Unlimited - String of restrictions description of the data migration for a user
//
Function DataTransferRestrictionsDescriptionFull(FilterSsettingsAtNode, CorrespondentVersion, SettingID) Export
	
	DocumentsDumpStartDateRestriction = "";
	RestrictionFilterByCompanies 			= "";
	
	// Document export start date
	If ValueIsFilled(FilterSsettingsAtNode.DocumentsDumpStartDate) Then
		
		// "Export documents starting from January 1, 2009."
		NString = NStr("en = 'Beginning with %1'");
		
		DocumentsDumpStartDateRestriction = StringFunctionsClientServer.PlaceParametersIntoString(NString, Format(FilterSsettingsAtNode.DocumentsDumpStartDate, "DLF=DD"));
		
	Else
		
		DocumentsDumpStartDateRestriction = "For the whole period of accounting in application";
		
	EndIf;
	
	// Filter by companies
	If FilterSsettingsAtNode.UseCompaniesFilter Then
		
		FilterPresentationRow = StringFunctionsClientServer.GetStringFromSubstringArray(FilterSsettingsAtNode.Companies.Company, "; ");
		
		NString = NStr("en = 'Only by Companies: %1'");
		
		RestrictionFilterByCompanies = StringFunctionsClientServer.PlaceParametersIntoString(NString, FilterPresentationRow);
		
	Else
		
		RestrictionFilterByCompanies = NStr("en = 'By all companies'");
		
	EndIf;
	
	NString = NStr("en = 'Dump the documents and
		|directory
		|inquiries: %1 %2'");
	
	ParameterArray = New Array;
	ParameterArray.Add(DocumentsDumpStartDateRestriction);
	ParameterArray.Add(RestrictionFilterByCompanies);
	
	Return StringFunctionsClientServer.PlaceParametersIntoStringFromArray(NString, ParameterArray);
	
EndFunction

// Returns a string of default values description for a user;
// Application developer creates a user-friendly description string based on the default node values.
// 
// Parameters:
//  DefaultValuesAtNode - Structure - structure of default values on the
//                                       exchange plan node received using the DefaultValuesOnNode() function.
// 
// Returns:
//  String, Unlimited - String of description for default values user
//
Function ValuesDescriptionFullByDefault(DefaultValuesAtNode, CorrespondentVersion, SettingID) Export
	
	Return "";
	
EndFunction

// Returns the command presentation of a new data exchange creation.
//
// Returns:
//  String, Unlimited - presentation of a command displayed in the user interface.
//
// ForExample:
// Return NStr("en = 'Create an exchange in the distributed infobase'");
//
Function CommandTitleForCreationOfNewDataExchange() Export
	
	Return NStr("en = 'Create exchange with configuration ""1C:Enterpreneur Reporting 8, version 1.0""'");
	
EndFunction

// Defines if the assistant of creating new exchange plan nodes is used.
//
// Returns:
//  Boolean - shows that assistant is used.
//
Function UseDataExchangeCreationAssistant() Export
	
	Return True;
	
EndFunction

// Returns a custom form for creation of the initial base image.
// This form will be opened when an exchange setting is complete using the assistant.
// For exchange plans not DIB function returns an empty row
//
// Returns:
//  String, Unlimited - form name
//
// ForExample:
// Return "ExchangePlan._DemoDistributedInfobase.Form.InitialImageCreationForm";
//
Function FormNameOfCreatingInitialImage() Export
	
	Return "";
	
EndFunction

// Returns an array of used messages transports for this exchange plan
//
// 1. For example if an exchange plan supports only two messages
// transports  FILE and FTP, then the body of the function should be defined in the following way:
//
// Result = New Array;
// Result.Add(Enums.ExchangeMessagesTransportKinds.FILE);
// Result.Add(Enums.ExchangeMessagesTransportKinds.FTP);
// Return Result;
//
// 2. For example if an exchange plan supports all messages
// transports defined in the configuration, then function body should be defined in the following way:
//
// Return DaraExchangeServer.AllConfigurationExchangeMessagesTransports();
//
// Returns:
//  Array - array contains values of the ExchangeMessagesTransportKinds enumeration
//
Function UsedTransportsOfExchangeMessages() Export
	
	Result = New Array;
	Result.Add(Enums.ExchangeMessagesTransportKinds.WS);
	Result.Add(Enums.ExchangeMessagesTransportKinds.FILE);
	
	Return Result;
	
EndFunction

Function CommonNodeData(CorrespondentVersion, FormName) Export
	
	Return "DocumentExportStartDate, Companies";
	
EndFunction

Procedure AccountingSettingsCheckHandler(Cancel, Recipient, Message) Export
	
	
EndProcedure

Function ExchangePlanUsedSaaS() Export
	
	Return True;
	
EndFunction

Function AccountingSettingsSetupComment() Export
	
	Return "";
	
EndFunction

// Returns the string with brief description of data exchange displayed on the first page of Data exhange creation assistant.
// 
// Used starting from SSL 2.1.2
//
Function BriefInformationOnExchange(SettingID) Export
	
	ExplanationText = NStr("en = '	Enables data synchronization between 1C:Small Business, version 1.5 and 1C:Enterpreneur Reporting version 2.0. Synchronization is unilateral. From Small Business to Enterpreneur Reporting all necessary data is transferred to prepare and submit the reporting. For more information click Detailed description.'");
	
	Return ExplanationText;
	
EndFunction // BriefInformationOnExchange()

// Returns link to a web page or full path to the form inside the configuration as a string
// 
Function DetailedInformationAboutExchange(SettingID) Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return "ExchangePlan.ExchangeSmallBusinessEntrepreneurReporting.Form.ExchangeDetailedInformationForm";
	EndIf;
	
	Return "";
	
EndFunction // DetailedInformationByExchange() 

// Procedure gets additional data used during setting an exchange in the correspondent base.
//
//  Parameters:
// AdditionalData - Structure. Additional data that
// will be used in the correspondent base during the exchange setting.
// Only values supporting XDTO-serialization are applied as structure values.
//
Procedure GetMoreDataForCorrespondent(AdditionalInformation) Export
	
EndProcedure

// Returns the name of configurations family. 
// Used to support exchanges with configurations changes in service.
//
Function SourceConfigurationName() Export
	
	Return "SmallBusiness";
	
EndFunction // SourceConfigurationName()

//////////////////////////////////////////////////////////////////////////////
// FUNCTIONS FOR EXCHANGE THROUGH EXTERNAL CONNECTION

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
Function CorrespondentInfobaseNodeFilterSetup(CorrespondentVersion, FormName, SettingID) Export
	
	CounterpartyTabularSectionStructure = New Structure;
	CounterpartyTabularSectionStructure.Insert("Company", New Array);
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("DocumentsDumpStartDate",      BegOfYear(CurrentDate()));
	SettingsStructure.Insert("UseCompaniesFilter",   False);
	SettingsStructure.Insert("Companies",                       CounterpartyTabularSectionStructure);
	
	Return SettingsStructure;
	
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
Function CorrespondentInfobaseNodeDefaultValues(CorrespondentVersion, FormName, SettingID) Export
	
	Return Undefined;
	
EndFunction

// Returns a description string of migration restrictions of the data for a correspondent base that is displayed to the user;
// Application developer creates a user-friendly restrictions description string based on the set filters in the correspondent base node.
// 
// Parameters:
//  FilterSsettingsAtNode - Structure - structure of filters on the node
//                                      of the exchange plan of a correspondent base received using the FiltersSettingOnCorrespondentBaseNode() function.
// 
// Returns:
//  String, Unlimited - String of restrictions description of the data migration for a user
//
Function CorrespondentInfobaseDataTransferRestrictionDetails(FilterSsettingsAtNode, CorrespondentVersion, SettingID) Export
	
	Return "";
	
EndFunction

// Returns a string of default values description for a correspondent base that is displayed to a user;
// Application developer creates a user-friendly description string based on the default values in the correspondent base node.
// 
// Parameters:
//  DefaultValuesAtNode - Structure - structure of default values on the exchange plan
//                                    node of the correspondent base received using the DefaultValuesOnCorrespondentBaseNode() function.
// 
// Returns:
//  String, Unlimited - String of description for default values user
//
Function CorrespondentInfobaseDefaultValueDetails(DefaultValuesAtNode, CorrespondentVersion, SettingID) Export
	
	Return "";
	
EndFunction

Function CorrespondentInfobaseAccountingSettingsSetupComment(CorrespondentVersion) Export
	
	Return "";
	
EndFunction

// Function returns the name of data export processor
//
Function DumpProcessingName() Export
	
	Return "ExportHandlersInEntrepreneurReporting";
	
EndFunction // ExportProcessorName()

// Function returns the name of data import processor
//
Function ImportProcessingName() Export
	
	Return "ImportHandlersFromEntrepreneurReporting";
	
EndFunction // ImportProcessorName()

// Function should return:
// True if the correspondent supports the exchange scenario in which the current IB works in local mode, while correspondent works in service model. 
// 
// False - if such exchange scenario is not supported.
//
Function CorrespondentSaaS() Export
	
	Return True;
	
EndFunction // CorrespondentSaaS()

////////////////////////////////////////////////////////////////////////////////
// OTHER PROCEDURES AND FUNCTIONS

//Returns the work script of the interactive match assistant 
//NotSend, InteractiveDocumentsSynchronization, InteractiveCatalogsSynchronization or any empty string
Function InitializeScriptJobsAssistantInteractiveExchange(InfobaseNode) Export
	
	Return "";
	
EndFunction

//Returns startup mode in case of interactive activation of synchronization
//Return values are AutomaticSynchronization Or InteractiveSynchronization
//On the basis of these values either interactive exchange assistant or automatic exchange is started
Function RunModeSynchronizationData(InfobaseNode) Export
	
	Return "";
	
EndFunction

//Returns the restrictions values of exchange plan nodes objects for interactive registration for exchange 
//Structure: AllDocuments, AllCatalogs, DetailedFilter
//Detailed filter or undefined, or array of metadata objects included into node structure (full name of metadata is specified)
Function AddGroupsRestrictions(InfobaseNode) Export
	//Example of standard return
	Return New Structure("AllDocuments, AllCatalogs, DetailedFilter", False, False, Undefined);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Handler of the event during connection to the correspondent.
// Event appears if the connection to correspondent is successful and configuration
// version of correspondent during exchange setting using assistant through
// a direct connection is received or if a correspondent is connected through the Internet.
// IN the handler, you can analyze correspondent version and 
// if an exchange setting is not supported by a correspondent of a specified version, then call an exception.
//
// Parameters:
// CorrespondentVersion (read only) - String - version of a correspondent configuration, for example, 2.1.5.1.
//
Procedure OnConnectingToCorrespondent(CorrespondentVersion) Export
	
EndProcedure

// Handler of the event during sending data of a node-sender.
// Event occurs during sending the data of node-sender from the
// current base to the correspondent before placing the data to exchange messages.
// You can change the sent data or deny sending the node data in the handler.
//
//  Parameters:
// Sender - ExchangePlanObject - exchange plan node from the name of which data is sent.
// Ignore - Boolean - shows that the node data export is denied.
//                    If you set the True value of this parameter in the handler,
//                    the data of node will not be sent. Default value - False.
//
Procedure OnDataSendingSender(Sender, Ignore) Export
	
EndProcedure

// Handler of the event during receiving data of a node-sender.
// Event appears during receiving data of a node-sender when 
// node data is read from an exchange message but not written to the infobase.
// You can change the received data or deny receiving the node data in the handler.
//
//  Parameters:
// Sender - ExchangePlanObject - exchange plan node from the name of which data is received.
// Ignore - Boolean - shows that the node data receipt is denied.
//                    If you set the True value of this parameter in the handler,
//                    the data of node will not be received. Default value - False.
//
Procedure OnSendersDataGet(Sender, Ignore) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overridable setting of export addon

// It is intended to set variants of online export setting by the node script.
// For setting you need to set parameters properties values to the required values.
//
// Parameters:
//     Recipient  - ExchangePlanRef - Node for which the settings are configure 
//     Parameters - Structure       - Parameters for change. Contains fields:
//
//         VariantNoneAdds - Structure     - settings of the "Do not add" typical variant.
//                                           Contains fields:
//             Use         - Boolean - flag of allowing to use variant. True by default.
//             Order       - Number  - order of a variant placement on the assistant form, downward. Default 1.
//             Title       - String  - allows to predefine the name of a typical variant.
//             Explanation - String  - allows to predefine a text of a variant explanation for a user.
//
//         VariantAllDocuments - Structure      - settings of the "Add all documents for the period" typical variant.
//                                                Contains fields:
//             Use         - Boolean - flag of allowing to use variant. True by default.
//             Order       - Number  - order of a variant placement on the assistant form, downward. Default 2.
//             Title       - String  - allows to predefine the name of a typical variant.
//             Explanation - String  - allows to predefine a text of a variant explanation for a user.
//
//         VariantArbitraryFilter - Structure - settings of the Add data with arbitrary selection typical variant.
//                                                Contains fields:
//             Use         - Boolean - flag of allowing to use variant. True by default.
//             Order       - Number  - order of a variant placement on the assistant form, downward. Default 3.
//             Title       - String  - allows to predefine the name of a typical variant.
//             Explanation - String  - allows to predefine a text of a variant explanation for a user.
//
//         VariantAdditionally - Structure      - additional variant settings by the node script.
//                                                Contains fields:
//             Use              - Boolean        - flag of allowing to use variant. False by default.
//             Order            - Number         - order of a variant placement on the assistant form, downward. Default 4.
//             Title            - String         - variant name for displaying on the form.
//             FormNameFilter   - String         - Name of the form called for settings editing.
//             FormCommandTitle - String         - Title for a rendering a settings form opening command in the form.
//             UsePeriodFilter  - Boolean        - check box showing that a common filter by a period is required. False by default.
//             FilterPeriod     - StandardPeriod - value of common filter period offered by default.
//
//             Filter           - ValueTable    - contains strings with detailed description of the filters by the node script.
//                                                            Contains columns:
//                 FullMetadataName - String                - full name of registered object metadata whose filter is described by the row.
//                                                            For example, Document._DemoProductsReceipt. You  can use the AllDocuments and  AllCatalogs  special  values
// for  filtering  all  documents  and  all  catalogs  being  registered  on  the  Recipient  node.
//                 PeriodSelection     - Boolean               - flag showing that this string describes the filter with the common period.
//                 Period              - StandardPeriod        - value of common filter period for row metadata line offered by default.
//                 Filter              - DataCompositionFilter - default filter. Selection fields are generated according to
//                                                               the general rules of generating template fields. For example, to specify
//                                                               a filter by the Company document attribute, you need to use the Ref.Company field
//
Procedure CustomizeInteractiveExporting(Recipient, Parameters) Export
	
	//
	// Usage example in demo SSL 2.1.5.12 (SW._DemoExchangeWithStandardSubsystemsLibrary)
	//
	
EndProcedure

// Returns filter presentation for an addition variant of export by a node script.
// See description of VarianAdditionally in the SetInteractiveExport procedure
//
// Parameters:
//     Recipient  - ExchangePlanRef - Node for which the presentation the filter is determined
//     Parameters - Structure       - Filter characteristics. Contains fields:
//         UsePeriodFilter - Boolean        - flag showing that you are required to use a common filter by period.
//         FilterPeriod    - StandardPeriod - value of general filter period.
//         Filter          - ValueTable     - contains strings with detailed description of the filters by the node script.
//                                                        Contains columns:
//                 FullMetadataName - String                - full name of registered object metadata whose filter is described by the row.
//                                                            For example, Document._DemoProductsReceipt. 
// The AllDocuments and AllCatalogs special values can be used for filtering all documents and all catalogs being registered on the
// Receiver node.
//                 PeriodSelection     - Boolean               - flag showing that this string describes the filter with the common period.
//                 Period              - StandardPeriod        - value of a common filter period for a row metadata.
//                 Filter              - DataCompositionFilter - filter fields. Selection fields are generated according to
//                                                               the general rules of generating template fields. For example, to specify
//                                                               a filter by the Company document attribute, the Ref.Company field will be used
//
// Returns: 
//     String - filter description
//
Function FilterPresentationInteractiveExportings(Recipient, Parameters) Export
	
	//
	// Usage example in demo SSL 2.1.5.12 (SW._DemoExchangeWithStandardSubsystemsLibrary)
	//
	
EndFunction

#EndIf