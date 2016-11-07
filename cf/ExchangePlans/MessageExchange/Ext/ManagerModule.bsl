#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ApplicationInterface

// Allows to predefine the exchange plan settings specified by default.
// Setting values default see in DataExchangeServer.ExchangePlanSettingsDefault.
// 
// Parameters:
// Settings - Structure - Contains settings default.
//
Procedure DefineSettings(Settings, SettingID) Export
	
	Settings.WarnAboutExchangeRulesVersionsMismatch = False;
	Settings.CommandTitleForCreationOfNewDataExchange = "";
	
EndProcedure

// Returns the settings attachment file name by default;
// the settings of an exchange for a receiver will be exported to this file;
// This value must be the same in the source exchange plan and receiver.
// 
// Returns:
// String - attachment file name default for setting export of data exchange.
//
Function SettingsFilenameForReceiver() Export
	
	Return "";
	
EndFunction

// Returns the filters structure on the exchange plan node with the set default values;
// Settings structure repeats the attributes content of header and exchange plan tabular sections;
// Structure items similar in key and value are used for
// header attributes. Structures containing arrays of
// tabular sections values of exchange plan parts are used for tabular sections.
// 
// Parameters:
// CorrespondentVersion - String - Correspondent version number. It is
// 								used for example for different setting content on a node for different correspondent versions.
// FormName - String - Used form name of node setting. Perhaps for
// 					example various form use for different correspondent versions.
// 
// Returns:
// SettingsStructure - Structure - Filter structure on the exchange plan node.
// 
Function FilterSsettingsAtNode(CorrespondentVersion, FormName, SettingID) Export
	
	Return New Structure;
	
EndFunction

// Returns the value structure default for a node;
// Structure of the settings repeats the content of exchange plan header attributes;
// For the header attributes structure items similar by key and the structure item value are used.
// 
// Parameters:
// CorrespondentVersion - String - Correspondent version number. It is used
// 								for example for different setting content default on a node for different correspondent versions.
// FormName - String - Used form name of value setting default.
// 					Perhaps for example various form use for different correspondent versions.
// 
// Returns:
//  SettingsStructure - Structure - value structure default on the exchange plan node.
// 
Function DefaultValuesAtNode(CorrespondentVersion, FormName, SettingID) Export
	
	Return New Structure;
	
EndFunction

// Returns a row of restrictions description of the migration data for a user;
// Applied developer based on set filters on the node should generate a row of restrictions description convenient for a user.
// 
// Parameters:
// FilterSsettingsAtNode - Structure - structure of filters on
// 									 node of an exchange plan received using the FiltersSettingsOnNode() function.
// CorrespondentVersion - String - Correspondent version number. It is used
// 								for example for different restriction description of data transfer depending on correspondent version.
// Returns:
// String - Restriction description row of data migration for user.
//
Function DataTransferRestrictionsDescriptionFull(FilterSsettingsAtNode, CorrespondentVersion, SettingID) Export
	
	Return "";
	
EndFunction

// Returns a string of default values description for a user;
// Application developer creates a user-friendly description string based on the default node values.
// 
// Parameters:
// DefaultValuesAtNode - Structure - structure of default values on the
// 										exchange plan node received using the DefaultValuesOnNode() function.
// CorrespondentVersion - String - Correspondent version number. It is used
// 								for example for different value description default depending on correspondent version.
// 
// Returns:
//  String - description row for value user default.
//
Function ValuesDescriptionFullByDefault(DefaultValuesAtNode, CorrespondentVersion, SettingID) Export
	
	Return "";
	
EndFunction

// Sets creation command presentation of new data exchange.
//
// Returns:
// String - presentation of a command displayed in the user interface.
//
Function CommandTitleForCreationOfNewDataExchange() Export
	
	Return "";
	
EndFunction

// Defines if the assistant of creating new exchange plan nodes is used.
//
// Returns:
//  Boolean - shows that assistant is used.
//
Function UseDataExchangeCreationAssistant() Export
	
	Return False;
	
EndFunction

// Defines the mechanism use of object registration.
//
// Returns:
// Boolean - True - if the object registration mechanism is required to use for current exchange plan.
// 		 False - if the object registration mechanism isn't required to use.
//
Function UseObjectChangeRecordMechanism() Export
	
	Return False;
	
EndFunction

// Returns a custom form for creation of the initial base image.
// This form will be opened when an exchange setting is complete using the assistant.
// For exchange plans not DIB function returns an empty row.
//
// Returns:
//  String - used form name.
//
// Example:
// Return ExchangePlan.ExchangeInDistributedInfobase.Form.InitialImageCreationForm;
//
Function FormNameOfCreatingInitialImage() Export
	
	Return "";
	
EndFunction

// Returns an array of used message transports for this exchange plan.
//
// Returns:
// Array - array contains enum values ExchangeMessageTransportKinds.
//
// Example:
// 1. If exchange plan supports only two message transports FILE and
// FTP then the function body should be defined the following way:
//
// Result = New Array;
// Result.Add(Enums.ExchangeMessagesTransportKinds.FILE);
// Result.Add(Enums.ExchangeMessagesTransportKinds.FTP);
// Return Result;
//
// 2. If exchange plan supports all message transports defined in
// configurations then the function body should be defined the following way:
//
// Return DaraExchangeServer.AllConfigurationExchangeMessagesTransports();
//
Function UsedTransportsOfExchangeMessages() Export
	
	Result = New Array;
	Result.Add(Enums.ExchangeMessagesTransportKinds.WS);
	Result.Add(Enums.ExchangeMessagesTransportKinds.FILE);
	Result.Add(Enums.ExchangeMessagesTransportKinds.FTP);
	Result.Add(Enums.ExchangeMessagesTransportKinds.EMAIL);
	
	Return Result;
	
EndFunction

// Sets sign of exchange plan use for exchange company in service model.
// If flag is selected, then in service you can
// enable data exchange using this exchange plan.
// If the flag is not selected, then the exchange
// plan will be used only for exchange in a local mode of configuration work.
//
// Returns:
// Boolean - Usage sign of exchange plan in service model.
//
Function ExchangePlanUsedSaaS() Export
	
	Return False;
	
EndFunction

// Returns a flag showing that an exchange plan supports data exchange with a correspondent working in a service model.
// If the flag is selected, then you can create a data exchange
// when this infobase works in a local mode and a correspondent works in a service model.
//
// Returns:
// Boolean - possibility sign of exchange setting with correspondent in service model.
//
Function CorrespondentSaaS() Export
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// For work through connection to a correspondent through external join or web service.

// Returns names of attributes and tabular sections of an
// exchange plan separated by commas that are common for an exchanging configurations pair.
//
// Parameters:
// CorrespondentVersion - String - Correspondent version number. It is used
// 								for example for different setting content of common node data depending on correspondent version.
// FormName - String - Used form name of value setting default.
// 					Perhaps for example various form use for different correspondent versions.
//
// Returns:
// String - list of properties details.
//
Function CommonNodeData(CorrespondentVersion, FormName) Export
	
	Return "";
EndFunction

// Returns the filters structure on the exchange plan node of correspondent base with set default values;
// Structure of the settings repeats the content of header attributes and tabular sections of an exchange plan of a correspondent base;
// Structure items similar in key and value are used for
// header attributes. Structures containing arrays of
// tabular sections values of exchange plan parts are used for tabular sections.
// 
// Parameters:
// CorrespondentVersion - String - Correspondent version number. It is
// 								used for example for different setting content on a node for different correspondent versions.
// FormName - String - Used form name of node setting. Perhaps for
// 					example various form use for different correspondent versions.
// 
// Returns:
//  SettingsStructure - Structure - filter structure on the exchange plan node of a correspondent base.
// 
Function CorrespondentInfobaseNodeFilterSetup(CorrespondentVersion, FormName, SettingID) Export
	
	Return New Structure;
EndFunction

// Returns value structure default for a correspondent base node;
// Settings structure repeats the attributes content of exchange plan header of a correspondent base;
// For the header attributes structure items similar by key and the structure item value are used.
// 
// Parameters:
// CorrespondentVersion - String - Correspondent version number. It is used
// 								for example for different setting content default on a node for different correspondent versions.
// FormName - String - Used form name of value setting default.
// 					Perhaps for example various form use for different correspondent versions.
// 
// Returns:
//  SettingsStructure - Structure - value structure default on the exchange plan node of a correspondent base.
//
Function CorrespondentInfobaseNodeDefaultValues(CorrespondentVersion, FormName, SettingID) Export
	
	Return New Structure;
EndFunction

// Returns a description string of migration restrictions of the data for a correspondent base that is displayed to the user;
// Application developer creates a user-friendly restrictions description string
// based on the set filters in the correspondent base node.
// 
// Parameters:
// FilterSsettingsAtNode - Structure - structure of filters on the node
//                                       of the exchange plan of a correspondent base received using the FiltersSettingOnCorrespondentBaseNode() function.
// CorrespondentVersion - String - Correspondent version number. It is used
// 								for example for different restriction description of data transfer depending on correspondent version.
// 
// Returns:
// String - restriction description row of data migration for user.
//
Function CorrespondentInfobaseDataTransferRestrictionDetails(FilterSsettingsAtNode, CorrespondentVersion, SettingID) Export
	
	Return "";
EndFunction

// Returns a string of default values description for a correspondent base that is displayed to a user;
// Application developer creates a user-friendly description string based
// on the
// default values in the correspondent base node.
// 
// Parameters:
//  DefaultValuesAtNode - Structure - structure of default values on the exchange plan
//                                       node of the correspondent base received using the DefaultValuesOnCorrespondentBaseNode() function.
// CorrespondentVersion - String - Correspondent version number. It is used
// 								for example for different value description default depending on correspondent version.
// 
// Returns:
//  String - description row for value user default.
//
Function CorrespondentInfobaseDefaultValueDetails(DefaultValuesAtNode, CorrespondentVersion, SettingID) Export
	
	Return "";
EndFunction

// Defines the explanation text for accounting parameter setting of base-correspondent.
// 
// Parameters:
// CorrespondentVersion - String - Correspondent version number. It is used
// 								for example for different explanation for accounting parameter setting depending on correspondent version.
// 
// Returns:
//  String - explanation description row for accounting parameter setting of base-correspondent.
//
Function CorrespondentInfobaseAccountingSettingsSetupComment(CorrespondentVersion) Export
	
	Return "";
EndFunction

// Procedure gets additional data used during setting an exchange in the correspondent base.
//
// Parameters:
// AdditionalInformation - Structure. Additional data that
// will be used in the correspondent base during the exchange setting.
// Only values supporting XDTO-serialization are applied as structure values.
//
Procedure GetMoreDataForCorrespondent(AdditionalInformation) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Handler of the event during connection to the correspondent.
// Event appears if the connection to correspondent is successful and configuration
// version of correspondent during exchange setting using assistant through
// a direct connection is received or if a correspondent is connected through the Internet.
// IN the handler, you can analyze
// correspondent version and if an exchange setting is not supported by a correspondent of a specified version, then call an exception.
//
//  Parameters:
// CorrespondentVersion (read only) - String - correspondent configuration version for example "2.1.5.1".
//
Procedure OnConnectingToCorrespondent(CorrespondentVersion) Export
	
EndProcedure

// Handler of the event during sending data of a node-sender.
// Event occurs during sending the data of node-sender from the
// current base to the correspondent before placing the data to exchange messages.
// You can change the sent data or deny sending the node data in the handler.
//
//  Parameters:
// Sender - ExchangePlanObject - exchange plan node from which the data sending is executing.
// Ignore - Boolean - cancel sign from node data export.
//                         If you set the True value of
//                         this parameter in the handler, the data of node will not be sent. Value by default - False.
//
Procedure OnDataSendingSender(Sender, Ignore) Export
	
EndProcedure

// Handler of the event during receiving data of a node-sender.
// Event appears during receiving
// data of a node-sender when node data is read from an exchange message but not written to the infobase.
// You can change the received data or deny receiving the node data in the handler.
//
//  Parameters:
// Sender - ExchangePlanObject - exchange plan node from which the data receive is executing.
// Ignore - Boolean - cancel sign from node data getting.
//                         If you set the True value of
//                         this parameter in the handler, the data of node will not be received. Value by default - False.
//
Procedure OnSendersDataGet(Sender, Ignore) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Constants and checking of accounting parameters.

// Defines the explanation text for accounting parameter setting.
// 
// Returns:
// String - explanation description row for accounting parameter setting.
//
Function AccountingSettingsSetupComment() Export
	
	Return "";
	
EndFunction

// Checks accounting parameter setting correctness.
//
// Parameters:
// Cancel - Boolean - Sign of exchange setting continuing impossibility due to incorrectly configured accounting parameters.
// Recipient - ExchangePlanRef - Exchange node for which checking accounting parameters is executing.
// Message - String - Contains the message text about incorrect accounting parameters.
//
Procedure AccountingSettingsCheckHandler(Cancel, Recipient, Message) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Objects bulk edit.

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
// Returns:
// Array - Contains attribute names banned for editing.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

#EndRegion

#EndIf