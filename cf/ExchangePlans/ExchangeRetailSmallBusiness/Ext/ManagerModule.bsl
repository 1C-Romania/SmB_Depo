#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ApplicationInterface

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
	
	Return NStr("en='SB-RT exchange settings';ru='Настройки обмена УНФ-РТ'");
	
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
	
	WarehousesTabularSectionStructure = New Structure;
	WarehousesTabularSectionStructure.Insert("Warehouse",           New Array);
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("DocumentsDumpStartDate",      BegOfYear(CurrentSessionDate()));
	SettingsStructure.Insert("UseCompaniesFilter",   False);
	SettingsStructure.Insert("UseFilterByWarehouses",        False);
	SettingsStructure.Insert("Companies",                       CounterpartyTabularSectionStructure);
	SettingsStructure.Insert("Warehouses",                            WarehousesTabularSectionStructure);
	
	SettingsStructure.Insert("DocumentsExportMode",                 Enums.ExchangeObjectsExportModes.ExportByCondition);
	SettingsStructure.Insert("CatalogsExportMode",               Enums.ExchangeObjectsExportModes.ExportByCondition);
	SettingsStructure.Insert("CorrespondentDocumentsExportMode",   Enums.ExchangeObjectsExportModes.ExportByCondition);
	SettingsStructure.Insert("CorrespondentCatalogsExportMode", Enums.ExchangeObjectsExportModes.ExportByCondition);
	
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
//  Row, Unlimited. - String of restrictions description of the data migration for a user
//
Function DataTransferRestrictionsDescriptionFull(FilterSsettingsAtNode, CorrespondentVersion, SettingID) Export
	
	DocumentsPresentation = "";
	RegulatoryReferenceInformationPresentation = "";
	DataSendingRestrictionsPresentation = "";
	
	// Documents presentation
	If FilterSsettingsAtNode.DocumentsExportMode = Enums.ExchangeObjectsExportModes.ExportByCondition Then
		
		PeriodPresentation = "";
		
		If ValueIsFilled(FilterSsettingsAtNode.DocumentsDumpStartDate) Then
			PeriodPresentation = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en=', beginning with %1';ru=', начиная с %1'"),
				Format(FilterSsettingsAtNode.DocumentsDumpStartDate, "DLF=DD"));
		Else
			PeriodPresentation = NStr("en=' for the whole period of accounting in application.';ru=' за весь период ведения учета в программе.'");
		EndIf;
		
		DocumentsPresentation = NStr("en='Send documents [PeriodPresentation]';ru='Отправлять документы[ПредставлениеПериода]'");
		
		DocumentsPresentation = StrReplace(DocumentsPresentation, "[PeriodPresentation]", PeriodPresentation);
		
	ElsIf FilterSsettingsAtNode.DocumentsExportMode = Enums.ExchangeObjectsExportModes.ExportManually Then
		
		DocumentsPresentation = NStr("en='Send documents only manually.';ru='Отправлять документы только вручную.'");
		
	ElsIf FilterSsettingsAtNode.DocumentsExportMode = Enums.ExchangeObjectsExportModes.DoNotExport Then
		
		DocumentsPresentation = NStr("en='Do not send documents.';ru='Не отправлять документы.'");
		
	EndIf;
	
	// Reference information
	If FilterSsettingsAtNode.CatalogsExportMode = Enums.ExchangeObjectsExportModes.ExportByCondition Then
		
		RegulatoryReferenceInformationPresentation = NStr("en='Send all reference information.';ru='Отправлять всю нормативно-справочную информацию.'");
		
	ElsIf FilterSsettingsAtNode.CatalogsExportMode = Enums.ExchangeObjectsExportModes.ExportIfNecessary Then
		
		RegulatoryReferenceInformationPresentation = NStr("en='Send reference information used in the sent documents.';ru='Отправлять нормативно-справочную информацию, которая используется в отправляемых документах.'");
		
	ElsIf FilterSsettingsAtNode.CatalogsExportMode = Enums.ExchangeObjectsExportModes.DoNotExport Then
		
		RegulatoryReferenceInformationPresentation = NStr("en='Do not send reference information.';ru='Не отправлять нормативно-справочную информацию.'");
		
	EndIf;
	
	// Presentation of the data sending restrictions
	If (FilterSsettingsAtNode.DocumentsExportMode = Enums.ExchangeObjectsExportModes.ExportByCondition)
		OR (FilterSsettingsAtNode.DocumentsExportMode = Enums.ExchangeObjectsExportModes.ExportManually)
		OR (FilterSsettingsAtNode.CatalogsExportMode = Enums.ExchangeObjectsExportModes.ExportByCondition) Then
		
		CompaniesPresentation = "";
		WarehousesPresentation = "";
		
		// Filter by companies
		If FilterSsettingsAtNode.UseCompaniesFilter Then
			FilterPresentationRow = StringFunctionsClientServer.GetStringFromSubstringArray(
				FilterSsettingsAtNode.Companies.Company,
				"; ");
			CompaniesPresentation = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Only by companies: %1.';ru='Только по организациям: %1.'"),
				FilterPresentationRow);
		Else
			CompaniesPresentation = NStr("en='By all companies.';ru='По всем организациям.'");
		EndIf;
		
		// filter by warehouses
		If FilterSsettingsAtNode.UseFilterByWarehouses Then
			FilterPresentationRow = StringFunctionsClientServer.GetStringFromSubstringArray(
				FilterSsettingsAtNode.Warehouses.Warehouse,
				"; ");
			WarehousesPresentation = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Only by warehouses: %1.';ru='Только по складам: %1.'"),
				FilterPresentationRow);
		Else
			WarehousesPresentation = NStr("en='By all warehouses.';ru='По всем складам.'");
		EndIf;
		
		DataSendingRestrictionsPresentation = NStr("en='Send
		|data:
		|[CompanyPresentation] [WarehousesPresentation]';ru='Отправлять
		|данные:
		|[ПредставлениеОрганизаций] [ПредставлениеСкладов]'");
		
		DataSendingRestrictionsPresentation = StrReplace(DataSendingRestrictionsPresentation, "[CompaniesPresentation]", CompaniesPresentation);
		DataSendingRestrictionsPresentation = StrReplace(DataSendingRestrictionsPresentation, "[WarehousesPresentation]", WarehousesPresentation);
		
	EndIf;
	
	Result = NStr("en='[DocumentsPresentation] [RegulatoryAndReferenceInformationPresentation] [DataSendingRestrictionsPresentation]';ru='[ПредставлениеДокументов] [ПредставлениеНормативноСправочнойИнформации] [ПредставлениеОграниченийОтправкиДанных]'");
	
	Result = StrReplace(Result, "[DocumentsPresentation]", DocumentsPresentation);
	Result = StrReplace(Result, "[RegulatoryReferenceInformationPresentation]", RegulatoryReferenceInformationPresentation);
	Result = StrReplace(Result, "[DataSendingRestrictionsPresentation]", DataSendingRestrictionsPresentation);
	
	Return Result;
EndFunction

// Returns a string of default values description for a user;
// Application developer creates a user-friendly description string based on the default node values.
// 
// Parameters:
//  DefaultValuesAtNode - Structure - structure of default values on the
//                                       exchange plan node received using the DefaultValuesOnNode() function.
// 
// Returns:
//  Row, Unlimited. - description string for default values user
//
Function ValuesDescriptionFullByDefault(DefaultValuesAtNode, CorrespondentVersion, SettingID) Export
	
	Return "";
	
EndFunction

// Returns the command presentation of a new data exchange creation.
//
// Returns:
//  Row, Unlimited - presentation of a command displayed in the user interface.
//
// ForExample:
// Return NStr("en='Create exchange in the distributed infobase';ru='Создать обмен в распределенной информационной базе'");
//
Function CommandTitleForCreationOfNewDataExchange() Export
	
	Return NStr("en='Create an exchange with 1C:Retail 8 2.1';ru='Создать обмен с конфигурацией ""1C: Розница 8, ред. 2.1'");
	
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
//  Row, Unlimited - form name
//
// ForExample:
// Return ExchangePlan.ExchangeInDistributedInfobase.Form.InitialImageCreationForm;
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
	Result.Add(Enums.ExchangeMessagesTransportKinds.COM);
	Result.Add(Enums.ExchangeMessagesTransportKinds.WS);
	Result.Add(Enums.ExchangeMessagesTransportKinds.FILE);
	Result.Add(Enums.ExchangeMessagesTransportKinds.FTP);
	Result.Add(Enums.ExchangeMessagesTransportKinds.EMAIL);
	
	Return Result;
	
EndFunction

// Returns a flag of using an exchange plan for an exchange organization in a service model.
//  If flag is selected, then in service you can
//  enable data exchange using this exchange plan.
//  If the flag is not selected, then the exchange plan will be used only for exchange in a local mode of configuration work.
// 
Function ExchangePlanUsedSaaS() Export
	
	Return True;
	
EndFunction

// Returns a flag showing that an exchange plan supports data exchange with a correspondent working in a service model.
// If the flag is selected, then you can create a data exchange
// when this infobase works in a local mode and a correspondent works in a service model.
//
Function CorrespondentSaaS() Export
	
	Return False;
	
EndFunction

// Returns a brief information on exchange output during setting of the data synchronization.
//
Function BriefInformationOnExchange(SettingID) Export
	
	ExplanationText = NStr("en='Allows you to synchronize data between 1C:Retail and 1C:Small business. Two-way synchronization helps you get the latest data in each infobase.';ru='Позволяет синхронизировать данные между программами 1С:Розница и 1С:Управление небольшой фирмой, Синхронизация является двухсторонней и позволяет иметь актуальные данные в каждой из информационных баз.'");
	
	Return ExplanationText;
	
EndFunction

// Return value: String - Ref to detailed information about
// the set synchronization as a hyperlink or a full path to a form
//
Function DetailedInformationAboutExchange(SettingID) Export
	
	Return "ExchangePlan.ExchangeRetailSmallBusiness.Form.DetailedInformation";
	
EndFunction

//Returns the work script of
//the interactive match assistant NotSend, InteractiveDocumentsSynchronization, InteractiveCatalogsSynchronization or any empty row
Function InitializeScriptJobsAssistantInteractiveExchange(InfobaseNode) Export
	
EndFunction

// Returns names of attributes and tabular sections of an
// exchange plan separated by commas that are common for an exchanging configurations pair.
//
Function CommonNodeData(CorrespondentVersion, FormName) Export
	
	FormName = "NodesSettingForm";
	
	Return "DocumentsExportStartDate, Companies, UseFilterByCompanies, CatalogsExportMode, CorrespondentCatalogsExportMode, DocumentsExportMode, CorrespondentDocumentsExportMode, ExportModeOnDemand";
	
EndFunction

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
	
	FormName = "CorrespondentInfobaseNodeSettingsForm";
	
	CounterpartyTabularSectionStructure = New Structure;
	CounterpartyTabularSectionStructure.Insert("Company",      New Array);
	CounterpartyTabularSectionStructure.Insert("Company_Key", New Array);
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("DocumentsDumpStartDate",      BegOfYear(CurrentSessionDate()));
	SettingsStructure.Insert("UseCompaniesFilter",   False);
	
	SettingsStructure.Insert("Companies",   CounterpartyTabularSectionStructure);
	
	SettingsStructure.Insert("DocumentsExportMode",                 Enums.ExchangeObjectsExportModes.ExportByCondition);
	SettingsStructure.Insert("CatalogsExportMode",               Enums.ExchangeObjectsExportModes.ExportByCondition);
	SettingsStructure.Insert("CorrespondentDocumentsExportMode",   Enums.ExchangeObjectsExportModes.ExportByCondition);
	SettingsStructure.Insert("CorrespondentCatalogsExportMode", Enums.ExchangeObjectsExportModes.ExportByCondition);
	
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
//                                       of the exchange plan of a correspondent base received using the FiltersSettingOnCorrespondentBaseNode() function.
// 
// Returns:
//  Row, Unlimited. - String of restrictions description of the data migration for a user
//
Function CorrespondentInfobaseDataTransferRestrictionDetails(FilterSsettingsAtNode, CorrespondentVersion, SettingID) Export
	
	If ValueIsFilled(FilterSsettingsAtNode.DocumentsDumpStartDate) Then
		DocumentsDumpStartDateRestriction = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Starting with %1';ru='Начиная с %1'"),
			Format(FilterSsettingsAtNode.DocumentsDumpStartDate, "DLF=DD"));
	Else
		DocumentsDumpStartDateRestriction = NStr("en='For the whole period of accounting in the application';ru='За весь период ведения учета в программе'");
	EndIf;
	
	// Filter by companies
	If FilterSsettingsAtNode.UseCompaniesFilter Then
		FilterPresentationRow = StringFunctionsClientServer.GetStringFromSubstringArray(
			FilterSsettingsAtNode.Companies.Company,
			"; ");
		RestrictionFilterByCompanies = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Only by Companies: %1';ru='Только по организациям: %1'"),
			FilterPresentationRow);
	Else
		RestrictionFilterByCompanies = NStr("en='By all companies';ru='по всем организациям'");
	EndIf;
	
	Return (
	NStr("en='Export documents and help information:';ru='Выгружать документы и справочную информацию:'")
		+ Chars.LF
		+ DocumentsDumpStartDateRestriction
		+ Chars.LF
		+ RestrictionFilterByCompanies
	);
	
EndFunction

Function CorrespondentInfobaseAccountingSettingsSetupComment(CorrespondentVersion) Export
	
EndFunction

// Returns a string of default values description for a correspondent base that is displayed to a user;
// Application developer creates a user-friendly description string based on the default values in the correspondent base node.
// 
// Parameters:
//  DefaultValuesAtNode - Structure - structure of default values on the exchange plan
//                                       node of the correspondent base received using the DefaultValuesOnCorrespondentBaseNode() function.
// 
// Returns:
//  Row, Unlimited. - description string for default values user
//
Function CorrespondentInfobaseDefaultValueDetails(DefaultValuesAtNode, CorrespondentVersion, SettingID) Export
	Return "";
EndFunction

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
////////////////////////////////////////////////////////////////////////////////
// Constants and checking of accounting parameters

Function AccountingSettingsSetupComment() Export
	
EndFunction

Procedure AccountingSettingsCheckHandler(Cancel, Recipient, Message) Export
	
EndProcedure

#EndRegion

#Region EventsHandlers

// Handler of the event during connection to the correspondent.
// Event appears if the connection to correspondent is successful and configuration
// version of correspondent during exchange setting using assistant through
// a direct connection is received or if a correspondent is connected through the Internet.
// IN the handler, you can analyze
// correspondent version and if an exchange setting is not supported by a correspondent of a specified version, then call an exception.
//
//  Parameters:
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
// Sender - ExchangePlanObject, Structure - exchange plan node on behalf of which the data is sent.
// Ignore - Boolean - shows that the node data export is denied.
//                         If you set the True value of
//                         this parameter in the handler, the data of node will not be sent. Default value - False.
//
Procedure OnDataSendingSender(Sender, Ignore) Export
	
EndProcedure

// Handler of the event during receiving data of a node-sender.
// Event appears during receiving
// data of a node-sender when node data is read from an exchange message but not written to the infobase.
// You can change the received data or deny receiving the node data in the handler.
//
//  Parameters:
// Sender - ExchangePlanObject, Structure - exchange plan node on behalf of which the data is received.
// Ignore - Boolean - shows that the node data receipt is denied.
//                         If you set the True value of
//                         this parameter in the handler, the data of node will not be received. Default value - False.
//
Procedure OnSendersDataGet(Sender, Ignore) Export
	
	If TypeOf(Sender) = Type("Structure") Then
		
		If Sender.Property("CatalogsExportMode") Then
			ChangeValues(Sender, "CatalogsExportMode", "CorrespondentCatalogsExportMode");
		EndIf;
		
		If Sender.Property("DocumentsExportMode") Then
			ChangeValues(Sender, "DocumentsExportMode", "CorrespondentDocumentsExportMode");
		EndIf;
		
	Else
		
		ChangeValues(Sender, "CatalogsExportMode", "CorrespondentCatalogsExportMode");
		ChangeValues(Sender, "DocumentsExportMode", "CorrespondentDocumentsExportMode");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PredefinedSetting

// It is intended to set variants of online export setting by the node script.
// For setting you need to set parameters properties values to the required values.
//
// Parameters:
//     Recipient - ExchangePlanRef - Node for which
//     the Parameters setting is executed  - Structure        - Parameters for change. Contains fields:
//
//         VariantNoneAdds - Structure     - settings of the "Do not add" typical variant.
//                                                Contains fields:
//             Use - Boolean - flag showing the permission to use variant. True by default.
//             Order       - Number  - order of a variant placement on the assistant form, downward. Default 1.
//             Title     - String - allows to predefine the name of a typical variant.
//             Explanation     - String - allows to predefine a text of a variant explanation for a user.
//
//         VariantAllDocuments - Structure      - settings of the "Add all documents for the period" typical variant.
//                                                Contains fields:
//             Use - Boolean - flag showing the permission to use variant. True by default.
//             Order       - Number  - order of a variant placement on the assistant form, downward. Default 2.
//             Title     - String - allows to predefine the name of a typical variant.
//             Explanation     - String - allows to predefine a text of a variant explanation for a user.
//
//         VariantArbitraryFilter - Structure - settings of the Add data with arbitrary selection typical variant.
//                                                Contains fields:
//             Use - Boolean - flag showing the permission to use variant. True by default.
//             Order       - Number  - order of a variant placement on the assistant form, downward. Default 3.
//             Title     - String - allows to predefine the name of a typical variant.
//             Explanation     - String - allows to predefine a text of a variant explanation for a user.
//
//         VariantAdditionally - Structure     - additional variant settings by the node script.
//                                                Contains fields:
//             Use            - Boolean            - flag showing the permission to use variant. False by default.
//             Order                  - Number             - order of a variant placement on the assistant form, downward. Default 4.
//             Title                - String            - variant name for displaying on the form.
//             FormNameFilter           - String            - Name of the form called for settings editing.
//             FormCommandTitle    - String            - Title for a rendering a settings form opening command in the form.
//             UsePeriodFilter - Boolean            - check box showing that a common filter by a period is required. False by default.
//             FilterPeriod             - StandardPeriod - value of common filter period offered by default.
//
//             Filter                    - ValueTable   - contains strings with detailed description of the filters by the node script.
//                                                            Contains columns:
//                 FullMetadataName - String                - full name of registered object metadata whose filter is described by the row.
//                                                               For example, Document._DemoProductsReceipt. You  can use the
// AllDocuments  and  AllCatalogs  special  values      for  filtering  all  documents  and  all  catalogs  being  registered  on  the  Recipient  node.
//                 PeriodSelection        - Boolean                - flag showing that this string describes the filter with the common period.
//                 Period              - StandardPeriod     - value of common filter period for row metadata line offered by default.
//                 Filter               - DataCompositionFilter - default filter. Selection fields are generated according to
//                                                               the general rules of generating layout fields. For example, to specify
//                                                               a filter by the Company document attribute, you need to use the Ref.Company field
//
Procedure CustomizeInteractiveExporting(Recipient, Parameters) Export
	
EndProcedure

// Returns filter presentation for an addition variant of
// export by a node script. See description of VarianAdditionally in the SetInteractiveExport procedure
//
// Parameters:
//     Recipient - ExchangePlanRef - Node for which the presentation
//     of the Parameters filter is determined  - Structure        - Filter characteristics. Contains fields:
//         UsePeriodFilter - Boolean            - flag showing that you are required to use a common filter by period.
//         FilterPeriod             - StandardPeriod - value of general filter period.
//         Filter                    - ValueTable   - contains strings with detailed description of the filters by the node script.
//                                                        Contains columns:
//                 FullMetadataName - String                - full name of registered object metadata whose filter is described by the row.
//                                                               For example, Document._DemoProductsReceipt. The AllDocuments and
// AllCatalogs special values can be used for filtering all documents and all catalogs being registered on the
// Receiver node.
//                 PeriodSelection        - Boolean                - flag showing that this string describes the filter with the common period.
//                 Period              - StandardPeriod     - value of a common filter period for a row metadata.
//                 Filter               - DataCompositionFilter - filter fields. Selection fields are generated according to
//                                                               the general rules of generating layout fields. For example, to specify
//                                                               a filter by the Company document attribute, the Ref.Company field will be used
//
// Returns: 
//     String - filter description
//
Function FilterPresentationInteractiveExportings(Recipient, Parameters) Export
	
	Return "";
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormKind = "ObjectForm" Then
		
		If Parameters.Property("Key") Then
			
			StandardProcessing = False;
			
			SelectedForm = "NodeForm";
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ChangeValues(Data, Val Property1, Val Property2)
	
	Value = Data[Property1];
	
	Data[Property1] = Data[Property2];
	Data[Property2] = Value;
	
EndProcedure

&AtServer
Procedure DefineImportDocumentsMode(Val SynchronizingDocumentsVariant, Val Data) Export
	
	If SynchronizingDocumentsVariant = "SendAndReceiveAutomatically" Then
		
		Data.DocumentsExportMode               = Enums.ExchangeObjectsExportModes.ExportByCondition;
		Data.CorrespondentDocumentsExportMode = Enums.ExchangeObjectsExportModes.ExportByCondition;
		
	ElsIf SynchronizingDocumentsVariant = "SendAutomatically" Then
		
		Data.DocumentsExportMode               = Enums.ExchangeObjectsExportModes.ExportByCondition;
		Data.CorrespondentDocumentsExportMode = Enums.ExchangeObjectsExportModes.ExportManually;
		
	ElsIf SynchronizingDocumentsVariant = "ReceiveAutomatically" Then
		
		Data.DocumentsExportMode               = Enums.ExchangeObjectsExportModes.ExportManually;
		Data.CorrespondentDocumentsExportMode = Enums.ExchangeObjectsExportModes.ExportByCondition;
		
	ElsIf SynchronizingDocumentsVariant = "SendAndReceiveManually" Then
		
		Data.DocumentsExportMode               = Enums.ExchangeObjectsExportModes.ExportManually;
		Data.CorrespondentDocumentsExportMode = Enums.ExchangeObjectsExportModes.ExportManually;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DefineCatalogsImportMode(Val CatalogsSynchronizingVariant, Val Data) Export
	
	If CatalogsSynchronizingVariant = "SendAndReceiveAutomatically" Then
		
		Data.CatalogsExportMode               = Enums.ExchangeObjectsExportModes.ExportByCondition;
		Data.CorrespondentCatalogsExportMode = Enums.ExchangeObjectsExportModes.ExportByCondition;
		
	ElsIf CatalogsSynchronizingVariant = "SendAndReceiveIfNecessary" Then
		
		Data.CatalogsExportMode               = Enums.ExchangeObjectsExportModes.ExportIfNecessary;
		Data.CorrespondentCatalogsExportMode = Enums.ExchangeObjectsExportModes.ExportIfNecessary;
		
	ElsIf CatalogsSynchronizingVariant = "SendAndReceiveManually" Then
		
		Data.CatalogsExportMode               = Enums.ExchangeObjectsExportModes.ExportManually;
		Data.CorrespondentCatalogsExportMode = Enums.ExchangeObjectsExportModes.ExportManually;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DefineDocumentsSynchronizationVariant(SynchronizingDocumentsVariant, Val Data) Export
	
	If Data.DocumentsExportMode                = Enums.ExchangeObjectsExportModes.ExportByCondition
		AND Data.CorrespondentDocumentsExportMode = Enums.ExchangeObjectsExportModes.ExportByCondition Then
		
		SynchronizingDocumentsVariant = "SendAndReceiveAutomatically"
		
	ElsIf Data.DocumentsExportMode           = Enums.ExchangeObjectsExportModes.ExportByCondition
		AND Data.CorrespondentDocumentsExportMode = Enums.ExchangeObjectsExportModes.ExportManually Then
		
		SynchronizingDocumentsVariant = "SendAutomatically"
		
	ElsIf Data.DocumentsExportMode           = Enums.ExchangeObjectsExportModes.ExportManually
		AND Data.CorrespondentDocumentsExportMode = Enums.ExchangeObjectsExportModes.ExportByCondition Then
		
		SynchronizingDocumentsVariant = "ReceiveAutomatically"
		
	ElsIf Data.DocumentsExportMode           = Enums.ExchangeObjectsExportModes.ExportManually
		AND Data.CorrespondentDocumentsExportMode = Enums.ExchangeObjectsExportModes.ExportManually Then
		
		SynchronizingDocumentsVariant = "SendAndReceiveManually"
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DefineCatalogsSynchronizationVariant(CatalogsSynchronizingVariant, Val Data) Export
	
	If Data.CatalogsExportMode                = Enums.ExchangeObjectsExportModes.ExportByCondition
		AND Data.CorrespondentCatalogsExportMode = Enums.ExchangeObjectsExportModes.ExportByCondition Then
		
		CatalogsSynchronizingVariant = "SendAndReceiveAutomatically"
		
	ElsIf Data.CatalogsExportMode           = Enums.ExchangeObjectsExportModes.ExportIfNecessary
		AND Data.CorrespondentCatalogsExportMode = Enums.ExchangeObjectsExportModes.ExportIfNecessary Then
		
		CatalogsSynchronizingVariant = "SendAndReceiveIfNecessary"
		
	ElsIf Data.CatalogsExportMode           = Enums.ExchangeObjectsExportModes.ExportManually
		AND Data.CorrespondentCatalogsExportMode = Enums.ExchangeObjectsExportModes.ExportManually Then
		
		CatalogsSynchronizingVariant = "SendAndReceiveManually"
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
