////////////////////////////////////////////////////////////////////////////////
// Update infobase of electronic documents library.
// 
/////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Returns the ElectronicDocuments library version number.
//
Function LibraryVersion() Export
	
	Return "1.2.5.3";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Receive information about library (or configuration).

// See description of the same procedure in the SSLInfobaseUpdate module.
Procedure OnAddSubsystem(Definition) Export
	
	Definition.Name    = "LibraryOfElectronicDocuments";
	Definition.Version = LibraryVersion();
	
	Definition.RequiredSubsystems.Add("StandardSubsystems");
	
EndProcedure

// See description of the same procedure in the SSLInfobaseUpdate module.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	// Handlers executed while filling an empty IB
	
	Handler = Handlers.Add();
	Handler.Version = "0.0.0.1";
	Handler.Procedure = "InfobaseUpdateED.FirstLaunch";
	Handler.InitialFilling = True;
	Handler.SharedData  = True;
	
	// New versions update handlers
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.4.0";
	Handler.Procedure = "Catalogs.EDUsageAgreements.RefreshDocumentKinds";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.0";
	Handler.Procedure = "InformationRegisters.DeleteEDExchangeMembersThroughEDFOperators.UpdateEDEScheduleVersion";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.3.5";
	Handler.Procedure = "InfobaseUpdateED.FillWorksWithCryptographyContext";
	Handler.SharedData = True;
	Handler.InitialFilling = True;
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.3.7";
	Handler.Procedure = "InformationRegisters.EDEventsLog.UpdateEDStatuses";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.6.3";
	Handler.Procedure = "Catalogs.EDUsageAgreements.FillFormatsVersions";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.7.4";
	Handler.Procedure = "Catalogs.EDUsageAgreements.FillFormatsVersionsOfOutgoingEDAndPackage";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.13.2";
	Handler.Procedure = "InformationRegisters.DeleteEDExchangeMembersThroughEDFOperators.ReplaceFrom1On2RegulationsVersionEDF";
	Handler.InitialFilling = False;

	Handler = Handlers.Add();
	Handler.Version = "1.1.13.4";
	Handler.Procedure = "Catalogs.EDAttachedFiles.FillFileDescription";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.13.6";
	Handler.Procedure = "Catalogs.EDUsageAgreements.UpdateOutgoingEDIPackFormatsVersions";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.14.2";
	Handler.Procedure = "Catalogs.EDUsageAgreements.FillCryptographyUsage";
	Handler.InitialFilling = False;

	Handler = Handlers.Add();
	Handler.Version = "1.1.14.2";
	Handler.Procedure = "Documents.RandomED.FillDocumentType";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version = "1.2.2.1";
	Handler.Procedure = "InfobaseUpdateED.FillDataAboutEDFProfileSettings";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version = "1.2.2.2";
	Handler.Procedure = "Catalogs.EDUsageAgreements.UpdateOutgoingED207FormatVersion_208";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version = "1.2.4.4";
	Handler.Procedure = "InfobaseUpdateED.TransferCryptographyContextSettings";
	Handler.PerformModes = "Exclusive";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version = "1.2.4.4";
	Handler.Procedure = "Catalogs.EDAttachedFiles.ChangeCustomEDSStatusesNotSentToFormed";
	Handler.PerformModes = "Exclusive";
	Handler.InitialFilling = False;
	
EndProcedure

// See description of the same procedure in the SSLInfobaseUpdate module.
Procedure BeforeInformationBaseUpdating() Export
	
EndProcedure

// See description of the same procedure in the SSLInfobaseUpdate module.
Procedure AfterInformationBaseUpdate(Val PreviousVersion, Val CurrentVersion,
		Val ExecutedHandlers, PutSystemChangesDescription, ExclusiveMode) Export
	
EndProcedure

// See description of the same procedure in the SSLInfobaseUpdate module.
Procedure OnPreparationOfUpdatesDescriptionTemplate(Val Template) Export
	

EndProcedure

// Non-interactive IB data update during the library version change.
// Mandatory IB update "entry point" in the library.
//
Procedure RunInfobaseUpdate() Export
	
	InfobaseUpdate.RunUpdateIteration(
		"LibraryOfElectronicDocuments", LibraryVersion(), UpdateHandlers());
	
EndProcedure

// Helps to override mode of the infobase data update.
// To use in rare (emergency) cases of transition that
// do not happen in a standard procedure of the update mode.
//
// Parameters:
//   DataUpdateMode - String - you can set one of the values in the handler:
//              InitialFilling     - if it is the first launch of an empty base (data field);
//              VersionUpdate        - if it is the first launch after the update of the data base configuration;
//              TransitionFromAnotherApplication - if first launch is run after the update of
// the data base configuration with changed name of the main configuration.
//
//   StandardProcessing  - Boolean - if you set False, then
//                                    a standard procedure of the update
//                                    mode fails and the DataUpdateMode value is used.
//
Procedure OnDefineDataUpdateMode(DataUpdateMode, StandardProcessing) Export
 
EndProcedure

// Adds procedure-processors of transition from another application to the list (with another configuration name).
// For example, for the transition between different but related configurations: base -> prof -> corp.
// Called before the beginning of the IB data update.
//
// Parameters:
//  Handlers - ValueTable - with columns:
//    * PreviousConfigurationName - String - name of the configuration, with which the transition is run;
//                                           or "*" if need perform when transition From any configuration.
//    * Procedure                 - String - full name of the procedure-processor of the transition from the PreviousConfigurationName application. 
//                                  ForExample, UpdatedERPInfobase.FillExportPolicy
//                                  is required to be export.
//
// Example of adding the procedure-processor to the list:
//  Handler = Handlers.Add();
//  Handler.PreviousConfigurationName  = TradeManagement;
//  Handler.Procedure                  = ERPInfobaseUpdate.FillAccountingPolicy;
//
Procedure OnAddTransitionFromAnotherApplicationHandlers(Handlers) Export
 
EndProcedure

// Called after all procedures-processors of transfer from another application (with another
// configuration name) and before beginning of the IB data update.
//
// Parameters:
//  PreviousConfigurationName    - String - name of configuration before transition.
//  PreviousConfigurationVersion - String - name of the previous configuration (before transition).
//  Parameters                    - Structure - 
//    * UpdateFromVersion   - Boolean - True by default. If you set
// False, only the mandatory handlers of the update will be run (with the * version).
//    * ConfigurationVersion           - String - version No after transition. 
//        By default it equals to the value of the configuration version in the metadata properties.
//        To run, for example, all update handlers from the PreviousConfigurationVersion version,
// you should set parameter value in PreviousConfigurationVersion.
//        To process all updates, set the 0.0.0.1 value.
//    * ClearInformationAboutPreviousConfiguration - Boolean - True by default. 
//        For cases when the previous configuration matches by name with the subsystem of the current configuration, set False.
//
Procedure OnEndTransitionFromAnotherApplication(Val PreviousConfigurationName, Val PreviousConfigurationVersion, Parameters) Export
 
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// Returns list of library update procedures-handlers for all supported IB versions.
//
// Example of adding the procedure-processor to the list:
//    Handler = Handlers.Add();
//    Handler.Version = "1.0.0.0";
//    Handler.Procedure = "IBUpdate.SwitchToVersion_1_0_0_0";
//    Handler.Optional = True;
//
// Called before the beginning of the IB data update.
//
Function UpdateHandlers()
	
	Handlers = InfobaseUpdate.NewUpdateHandlersTable();
	
	OnAddUpdateHandlers(Handlers);
	
	Return Handlers;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Empty IB filling

// Handler of the empty IB filling.
//
Procedure FirstLaunch() Export
	
	FillWorksWithCryptographyContext();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// New IB versions update

// Handler of ED kinds update with the relevant ones.
// Used if you need to add ED new kind to EDL catalogs.
//
// Parameters:
//  EDKind - EnumValue - enum value of EDKinds.
//
Procedure UpdateEDFSettings(EDKind) Export
	
	BeginTransaction();
	
	// Update items of the EDF settings profiles catalog.
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDFProfileSettings.Ref
	|FROM
	|	Catalog.EDFProfileSettings AS EDFProfileSettings
	|WHERE
	|	Not EDFProfileSettings.DeletionMark";
	
	Result = Query.Execute().Select();
	While Result.Next() Do
		
		DesiredSettingsProfile = Result.Ref.GetObject();
		WriteObject = False;
		
		EDRowKind = DesiredSettingsProfile.OutgoingDocuments.Find(EDKind, "OutgoingDocument");
		If EDRowKind = Undefined Then
			
			NewRow = DesiredSettingsProfile.OutgoingDocuments.Add();
			NewRow.OutgoingDocument         = EDKind;
			If ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
				"UseDigitalSignatures") Then
				NewRow.UseDS = True;
			EndIf;
			
			FormatVersion = "CML 2.08";
			If EDKind = Enums.EDKinds.RandomED Then
				
				FormatVersion = "";
			ElsIf EDKind = Enums.EDKinds.ActCustomer
				OR EDKind = Enums.EDKinds.ActPerformer
				OR EDKind = Enums.EDKinds.TORG12Customer
				OR EDKind = Enums.EDKinds.TORG12Seller
				OR EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient
				OR EDKind = Enums.EDKinds.AgreementAboutCostChangeSender Then
				
				FormatVersion = NStr("en='Federal Tax Service 5.01';ru='ФНС 5.01'");
			EndIf;
			NewRow.FormatVersion = FormatVersion;
			
			WriteObject = True;
		EndIf;
		
		If WriteObject Then
			InfobaseUpdate.WriteObject(DesiredSettingsProfile);
		EndIf;
		
	EndDo;
	
	// Update the EDF settings catalog items.
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreements.Ref
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	Not EDUsageAgreements.DeletionMark
	|	AND (EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEMail)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughDirectory)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughFTP))";
	
	Result = Query.Execute().Select();
	While Result.Next() Do
		
		DesiredSetting = Result.Ref.GetObject();
		WriteObject = False;
		
		EDRowKind = DesiredSetting.OutgoingDocuments.Find(EDKind, "OutgoingDocument");
		
		If EDRowKind = Undefined Then
			NewRow = DesiredSetting.OutgoingDocuments.Add();
			NewRow.OutgoingDocument         = EDKind;
			If ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
				"UseDigitalSignatures") Then
				NewRow.UseDS = True;
			EndIf;
			
			FormatVersion = "CML 2.08";
			If EDKind = Enums.EDKinds.RandomED Then
				
				FormatVersion = "";
			ElsIf EDKind = Enums.EDKinds.ActCustomer
				OR EDKind = Enums.EDKinds.ActPerformer
				OR EDKind = Enums.EDKinds.TORG12Customer
				OR EDKind = Enums.EDKinds.TORG12Seller
				OR EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient
				OR EDKind = Enums.EDKinds.AgreementAboutCostChangeSender Then
				
				FormatVersion = NStr("en='Federal Tax Service 5.01';ru='ФНС 5.01'");
			EndIf;
			NewRow.FormatVersion = FormatVersion;
			
			If DesiredSetting.AgreementSetupExtendedMode Then
				NewRow.EDFProfileSettings = DesiredSetting.OutgoingDocuments[0].EDFProfileSettings;
				NewRow.EDExchangeMethod = DesiredSetting.OutgoingDocuments[0].EDExchangeMethod;
				NewRow.CompanyID = DesiredSetting.OutgoingDocuments[0].CompanyID;
				NewRow.CounterpartyID = DesiredSetting.OutgoingDocuments[0].CounterpartyID;
			Else
				NewRow.EDFProfileSettings = DesiredSetting.EDFProfileSettings;
				NewRow.EDExchangeMethod = DesiredSetting.EDExchangeMethod;
				NewRow.CompanyID = DesiredSetting.CompanyID;
				NewRow.CounterpartyID = DesiredSetting.CounterpartyID;
			EndIf;
			
			WriteObject = True;
			
		EndIf;
		
		If WriteObject Then
			InfobaseUpdate.WriteObject(DesiredSetting);
		EndIf;
		
	EndDo;

	// Update the DS Certificates catalog items.
	Query.Text =
	"SELECT DISTINCT
	|	EDFProfileSettingsCompanySignatureCertificates.Certificate AS Certificate
	|INTO Certificates
	|FROM
	|	Catalog.EDFProfileSettings.CompanySignatureCertificates AS EDFProfileSettingsCompanySignatureCertificates
	|		LEFT JOIN Catalog.EDUsageAgreements AS EDUsageAgreements
	|		ON (EDUsageAgreements.EDFProfileSettings = EDFProfileSettingsCompanySignatureCertificates.Ref)
	|WHERE
	|	Not EDFProfileSettingsCompanySignatureCertificates.Certificate.DeletionMark
	|	AND Not EDFProfileSettingsCompanySignatureCertificates.Certificate.Revoked
	|	AND Not EDUsageAgreements.DeletionMark
	|	AND (EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEMail)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughDirectory)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughFTP))
	|
	|GROUP BY
	|	EDFProfileSettingsCompanySignatureCertificates.Certificate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Certificates.Certificate AS DSCertificate,
	|	DigitallySignedEDKinds.EDKind,
	|	DigitallySignedEDKinds.Use
	|FROM
	|	Certificates AS Certificates
	|		INNER JOIN InformationRegister.DigitallySignedEDKinds AS DigitallySignedEDKinds
	|		ON Certificates.Certificate.Ref = DigitallySignedEDKinds.DSCertificate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Certificates.Certificate AS DSCertificate
	|FROM
	|	Certificates AS Certificates";
	
	Result = Query.ExecuteBatch();
	Selection = Result[2].Select();
	VT = Result[1].Unload();
	Try
		While Selection.Next() Do
			Filter = New Structure("DSCertificate", Selection.DSCertificate);
			CopyOfVT = VT.Copy(Filter);
			WriteObject = False;
			
			EDRowKind = CopyOfVT.Find(EDKind, "EDKind");
			If EDRowKind = Undefined Then
				NewRow = CopyOfVT.Add();
				NewRow.EDKind        = EDKind;
				NewRow.Use = True;
				NewRow.DSCertificate = Selection.DSCertificate;
				WriteObject = True;
			ElsIf Not EDRowKind.Use Then
				EDRowKind.Use = True;
				WriteObject = True;
			EndIf;
			
			If WriteObject Then
				SaveSignedEDKinds(Selection.DSCertificate, CopyOfVT);
			EndIf;
		EndDo;
		CommitTransaction();
	Except
		OperationKind = NStr("en='Info base update';ru='Обновление информационной базы'");
		DetailErrorText = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(OperationKind, DetailErrorText);
		RollbackTransaction();
	EndTry;
	
EndProcedure

// Handler of the cryptography work context filling.
//
Procedure FillWorksWithCryptographyContext() Export
	
	ConstantWriting = Constants.AuthorizationContext.CreateValueManager();
	ConstantWriting.Value = Enums.WorkContextsWithED.AtClient;
	InfobaseUpdate.WriteData(ConstantWriting);
	
EndProcedure

// New EDFProfileSettings catalog appeared.
Procedure FillDataAboutEDFProfileSettings() Export
	
	BeginTransaction();
	
	// Mark for deletion irrelevant EDF settings.
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreements.Ref
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	Not EDUsageAgreements.DeletionMark
	|	AND EDUsageAgreements.AgreementStatus <> VALUE(Enum.EDAgreementsStatuses.Acts)
	|	AND EDUsageAgreements.ConnectionStatus = VALUE(Enum.EDExchangeMemberStatuses.EmptyRef)";
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		EDFSetup = Selection.Ref.GetObject();
		EDFSetup.SetDeletionMark(True);
		EDFSetup.Comment = NStr("en='##EDF setting is automatically marked for deletion during updating.';ru='##Настройка ЭДО помечена на удаление автоматически при обновлении.'");
		InfobaseUpdate.WriteObject(EDFSetup);
	EndDo;
	
	// Create items of the EDFProfileSettings catalog.
	// Check if an update was executed
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDFProfileSettings.Ref
	|FROM
	|	Catalog.EDFProfileSettings AS EDFProfileSettings";
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		
		IsUsedES = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
			"UseDigitalSignatures");
		
		Query = New Query;
		Query.Text =
		"SELECT DISTINCT
		|	EDUsageAgreements.Company,
		|	CAST(EDUsageAgreements.CompanyID AS String(100)) AS CompanyID,
		|	EDUsageAgreements.EDExchangeMethod,
		|	CASE
		|		WHEN EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom)
		|			THEN EDUsageAgreements.Ref
		|		ELSE TRUE
		|	END AS Ref,
		|	EDUsageAgreements.IncomingDocumentsResource,
		|	EDUsageAgreements.ServerAddress,
		|	EDUsageAgreements.User,
		|	EDUsageAgreements.Password,
		|	EDUsageAgreements.DeleteFTPPort AS Port,
		|	EDUsageAgreements.DeletePassiveFTPConnection AS PassiveConnection
		|FROM
		|	Catalog.EDUsageAgreements AS EDUsageAgreements
		|WHERE
		|	EDUsageAgreements.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)
		|	AND (EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom)
		|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEMail)
		|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughDirectory)
		|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughFTP))
		|	AND Not EDUsageAgreements.DeletionMark
		|	AND Not EDUsageAgreements.IsIntercompany";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			NewSettingsProfile = Catalogs.EDFProfileSettings.CreateItem();
			
			PatternName = NStr("en='%1, %2';ru='%1, %2'");
			NewSettingsProfile.Description = StringFunctionsClientServer.SubstituteParametersInString(PatternName,
			Selection.Company, Selection.EDExchangeMethod);
			
			NewSettingsProfile.Company              = Selection.Company;
			NewSettingsProfile.CompanyID = Selection.CompanyID;
			NewSettingsProfile.EDExchangeMethod           = Selection.EDExchangeMethod;
			
			EDActualKinds = ElectronicDocumentsReUse.GetEDActualKinds();
			For Each EnumValue IN EDActualKinds Do
				If EnumValue <> Enums.EDKinds.Confirmation
					AND EnumValue <> Enums.EDKinds.ProductsReturnBetweenCompanies
					AND EnumValue <> Enums.EDKinds.GoodsTransferBetweenCompanies
					AND EnumValue <> Enums.EDKinds.Confirmation
					AND EnumValue <> Enums.EDKinds.NotificationAboutClarification
					AND EnumValue <> Enums.EDKinds.Error
					AND EnumValue <> Enums.EDKinds.NotificationAboutReception
					AND EnumValue <> Enums.EDKinds.PaymentOrder
					AND EnumValue <> Enums.EDKinds.QueryStatement
					AND EnumValue <> Enums.EDKinds.BankStatement Then
					
					NewRow = NewSettingsProfile.OutgoingDocuments.Add();
					NewRow.ToForm = True;
					NewRow.OutgoingDocument = EnumValue;
					
					If ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
						"UseDigitalSignatures") Then
						NewRow.UseDS = True;
					EndIf;
					
					// Put exchange format version to new agreements of the direct exchange.
					FormatVersion = "CML 4.02";
					If EnumValue = Enums.EDKinds.RandomED Then
						FormatVersion = "";
					ElsIf EnumValue = Enums.EDKinds.ActCustomer
						OR EnumValue = Enums.EDKinds.ActPerformer
						OR EnumValue = Enums.EDKinds.TORG12Customer
						OR EnumValue = Enums.EDKinds.TORG12Seller
						OR EnumValue = Enums.EDKinds.AgreementAboutCostChangeSender
						OR EnumValue = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
						FormatVersion = NStr("en='Federal Tax Service 5.01';ru='ФНС 5.01'");
					ElsIf EnumValue = Enums.EDKinds.RightsDelegationAct Then
						FormatVersion = "CML 2.08";
					EndIf;
					NewRow.FormatVersion = FormatVersion;
				EndIf;
			EndDo;
			
			NewSettingsProfile.OutgoingDocuments.Sort("OutgoingDocument");
			
			// ED exchange settings
			If Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughDirectory Then
				DirectoryPath = Selection.IncomingDocumentsResource;
				PathStrings = CommonUseClientServer.SortStringByPointsAndSlashes(DirectoryPath);
				
				If PathStrings.Count() >= 1 Then
					NewName = PathStrings[PathStrings.Count() - 1];
				EndIf;
				DirectoryPath = StrReplace(DirectoryPath, NewName, "");
				NewSettingsProfile.IncomingDocumentsResource = DirectoryPath;
				
			ElsIf Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEMail Then
				NewSettingsProfile.IncomingDocumentsResource = Selection.IncomingDocumentsResource;
				
			ElsIf Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP Then
				NewSettingsProfile.ServerAddress             = Selection.ServerAddress;
				NewSettingsProfile.Port                     = Selection.Port;
				NewSettingsProfile.PassiveConnection      = Selection.PassiveConnection;
				NewSettingsProfile.Login                    = Selection.User;
				NewSettingsProfile.Password                   = Selection.Password;
				
				DirectoryPath = Selection.IncomingDocumentsResource;
				PathStrings = CommonUseClientServer.SortStringByPointsAndSlashes(DirectoryPath);
				
				If PathStrings.Count() >= 1 Then
					NewName = PathStrings[PathStrings.Count() - 1];
				EndIf;
				DirectoryPath = StrReplace(DirectoryPath, NewName, "");
				NewSettingsProfile.IncomingDocumentsResource = DirectoryPath;
				
			ElsIf Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
				
				// Certificate settings - transfer to profile.
				For Each String IN Selection.Ref.CompanySignatureCertificates Do
					NewRow = NewSettingsProfile.CompanySignatureCertificates.Add();
					NewRow.Certificate = String.Certificate;
				EndDo;
			EndIf;
			
			InfobaseUpdate.WriteObject(NewSettingsProfile);

		EndDo;
	EndIf;
	
	// Update i/r EDExchangeStatesViaEDFOperators
	RecordSet = InformationRegisters.EDExchangeStatesThroughEDFOperators.CreateRecordSet();
	RecordSet.Read();
	
	For Each Record IN RecordSet Do
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	EDFProfileSettings.Ref
		|FROM
		|	Catalog.EDFProfileSettings AS EDFProfileSettings
		|WHERE
		|	EDFProfileSettings.EDExchangeMethod = &EDExchangeMethod
		|	AND EDFProfileSettings.Company = &Company";
		
		Query.SetParameter("Company",    Record.DeleteAgreementAboutEDUsage.Company);
		Query.SetParameter("EDExchangeMethod", Record.DeleteAgreementAboutEDUsage.EDExchangeMethod);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Record.EDFProfileSettings = Selection.Ref;
		EndIf;
	
	EndDo;
	
	InfobaseUpdate.WriteData(RecordSet);
	
	// Update the direct exchange agreements.
	// Check if the direct exchange settings are unique.
	// Mark extra settings for deletion.
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	COUNT(EDUsageAgreements.Ref) AS Ref,
	|	EDUsageAgreements.Counterparty
	|INTO CounterpartiesDuplicates
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	(EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEMail)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughDirectory)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughFTP))
	|	AND EDUsageAgreements.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)
	|	AND Not EDUsageAgreements.DeletionMark
	|
	|GROUP BY
	|	EDUsageAgreements.Counterparty
	|
	|HAVING
	|	COUNT(EDUsageAgreements.Ref) > 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EDUsageAgreements.Ref,
	|	EDUsageAgreements.Counterparty AS Counterparty
	|FROM
	|	CounterpartiesDuplicates AS CounterpartiesDuplicates
	|		LEFT JOIN Catalog.EDUsageAgreements AS EDUsageAgreements
	|		ON CounterpartiesDuplicates.Counterparty = EDUsageAgreements.Counterparty
	|WHERE
	|	(EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEMail)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughDirectory)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughFTP))
	|	AND EDUsageAgreements.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)
	|	AND Not EDUsageAgreements.DeletionMark
	|
	|ORDER BY
	|	Counterparty";
	Selection = Query.Execute().Select();
	DesiredCounterparty = "";
	While Selection.Next() Do
		
		If DesiredCounterparty = Selection.Counterparty Then
			EDFSetup = Selection.Ref.GetObject();
			EDFSetup.SetDeletionMark(True);
			EDFSetup.Comment = NStr("en='##EDF setting is automatically marked for deletion during updating.';ru='##Настройка ЭДО помечена на удаление автоматически при обновлении.'");
			InfobaseUpdate.WriteObject(EDFSetup);
		Else
			DesiredCounterparty = Selection.Counterparty;
		EndIf;
	EndDo;
	
	// Fill in the missing information in EDF settings.
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	EDUsageAgreements.Ref,
	|	EDFProfileSettings.Ref AS EDFProfileSettings,
	|	CAST(EDUsageAgreements.CounterpartyID AS String(100)) AS CounterpartyID,
	|	CAST(EDUsageAgreements.CompanyID AS String(100)) AS CompanyID,
	|	EDUsageAgreements.Counterparty,
	|	EDUsageAgreements.EDExchangeMethod,
	|	EDUsageAgreements.IncomingDocumentsResource,
	|	EDUsageAgreements.OutgoingDocumentsResource
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|		LEFT JOIN Catalog.EDFProfileSettings AS EDFProfileSettings
	|		ON EDUsageAgreements.EDExchangeMethod = EDFProfileSettings.EDExchangeMethod
	|			AND EDUsageAgreements.Company = EDFProfileSettings.Company
	|WHERE
	|	(EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEMail)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughDirectory)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughFTP))
	|	AND EDUsageAgreements.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)
	|	AND Not EDUsageAgreements.DeletionMark
	|	AND Not EDUsageAgreements.IsIntercompany";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		EDFSetup = Selection.Ref.GetObject();
		
		EDFSetup.Description       = String(Selection.Counterparty);
		EDFSetup.EDFProfileSettings = Selection.EDFProfileSettings;

		EDSourceTable = EDFSetup.OutgoingDocuments.Unload();
		
		EDSourceTable.FillValues(Selection.EDFProfileSettings,       "EDFProfileSettings");
		EDSourceTable.FillValues(Selection.EDExchangeMethod,           "EDExchangeMethod");
		EDSourceTable.FillValues(Selection.CompanyID, "CompanyID");
		EDSourceTable.FillValues(Selection.CounterpartyID, "CounterpartyID");
		
		EDFSetup.OutgoingDocuments.Load(EDSourceTable);
		
		// Add missing documents to TS outgoing documents for the direct exchange.
		
		EDFSetup.OutgoingDocuments.Sort("OutgoingDocument");
		
		EDFSetup.ConnectionStatus   = Enums.EDExchangeMemberStatuses.Connected;
		EDFSetup.AgreementState = Enums.EDAgreementStates.Acts;
		
		If ValueIsFilled(EDFSetup.CompanyCertificateForDetails) Then
			EncryptEDPackageData = True;
		EndIf;
		If EDFSetup.CounterpartySignaturesCertificates.Count() > 0 Then
			VerifySignatureCertificates = True;
		EndIf;
		
		// ED exchange settings
		If Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughDirectory Then
			IncomingDirectoryPath = Selection.Ref.IncomingDocumentsResource;
			OutcomingDirectoryPath = Selection.Ref.OutgoingDocumentsResource;
			IncomingDirectoryPathStrings = CommonUseClientServer.SortStringByPointsAndSlashes(IncomingDirectoryPath);
			OutgoingDirectoryPathStrings = CommonUseClientServer.SortStringByPointsAndSlashes(OutcomingDirectoryPath);
			
			If IncomingDirectoryPathStrings.Count() >= 1 Then
				IncomingDirectoryNewName = IncomingDirectoryPathStrings[IncomingDirectoryPathStrings.Count() - 1];
			EndIf;
			If OutgoingDirectoryPathStrings.Count() >= 1 Then
				OutgoingDirectoryNewName = OutgoingDirectoryPathStrings[OutgoingDirectoryPathStrings.Count() - 1];
			EndIf;
			EDFSetup.IncomingDocumentsDir = IncomingDirectoryNewName;
			EDFSetup.OutgoingDocumentsDir = OutgoingDirectoryNewName;
			
		ElsIf Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEMail Then
			EDFSetup.CounterpartyEmail = Selection.OutgoingDocumentsResource;
		
		ElsIf Selection.EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP Then
			IncomingDirectoryPath = Selection.Ref.IncomingDocumentsResource;
			OutcomingDirectoryPath = Selection.Ref.OutgoingDocumentsResource;
			IncomingDirectoryPathStrings = CommonUseClientServer.SortStringByPointsAndSlashes(IncomingDirectoryPath);
			OutgoingDirectoryPathStrings = CommonUseClientServer.SortStringByPointsAndSlashes(OutcomingDirectoryPath);
			
			If IncomingDirectoryPathStrings.Count() >= 1 Then
				IncomingDirectoryNewName = IncomingDirectoryPathStrings[IncomingDirectoryPathStrings.Count()-1];
				
			ElsIf IncomingDirectoryPathStrings.Count() = 1 Then
				IncomingDirectoryNewName = IncomingDirectoryPathStrings[0];
			EndIf;
			If OutgoingDirectoryPathStrings.Count() >= 1 Then
				OutgoingDirectoryNewName = OutgoingDirectoryPathStrings[OutgoingDirectoryPathStrings.Count()-1];
				
			ElsIf OutgoingDirectoryPathStrings.Count() = 1 Then
				OutgoingDirectoryNewName = OutgoingDirectoryPathStrings[0];
			EndIf;
			EDFSetup.IncomingDocumentsDirFTP = IncomingDirectoryNewName;
			EDFSetup.OutgoingDocumentsDirFTP = OutgoingDirectoryNewName;
		EndIf;
		
		InfobaseUpdate.WriteObject(EDFSetup);

	EndDo;
	
	// Update exchange agreements via operator.
	Query = New Query;
	Query.Text =
	"SELECT
	|	DeleteEDExchangeMembersThroughEDFOperators.AgreementAboutEDUsage,
	|	DeleteEDExchangeMembersThroughEDFOperators.Participant,
	|	DeleteEDExchangeMembersThroughEDFOperators.EMail_Address,
	|	DeleteEDExchangeMembersThroughEDFOperators.EDFScheduleVersion,
	|	DeleteEDExchangeMembersThroughEDFOperators.StatusModificationDate,
	|	DeleteEDExchangeMembersThroughEDFOperators.ID,
	|	DeleteEDExchangeMembersThroughEDFOperators.Status,
	|	DeleteEDExchangeMembersThroughEDFOperators.EDExchangeFilesFormat,
	|	DeleteEDExchangeMembersThroughEDFOperators.ErrorDescription,
	|	DeleteEDExchangeMembersThroughEDFOperators.AgreementAboutEDUsage.Company AS Company
	|FROM
	|	InformationRegister.DeleteEDExchangeMembersThroughEDFOperators AS DeleteEDExchangeMembersThroughEDFOperators
	|WHERE
	|	DeleteEDExchangeMembersThroughEDFOperators.AgreementAboutEDUsage.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)
	|	AND Not DeleteEDExchangeMembersThroughEDFOperators.AgreementAboutEDUsage.DeletionMark";
	
	ParticipantsSelection = Query.Execute().Select();
	While ParticipantsSelection.Next() Do
		
		If Not ParticipantsSelection.AgreementAboutEDUsage.DeletionMark Then
			EDFSetup = ParticipantsSelection.AgreementAboutEDUsage.GetObject();
			EDFSetup.SetDeletionMark(True);
			EDFSetup.Description = NStr("en=""Don't use"";ru='Не использовать'") + " - " + EDFSetup.Description;
			EDFSetup.Comment = NStr("en='##EDF setting is automatically marked for deletion during updating.';ru='##Настройка ЭДО помечена на удаление автоматически при обновлении.'");
			InfobaseUpdate.WriteObject(EDFSetup);
		EndIf;
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	EDFProfileSettings.Ref
		|FROM
		|	Catalog.EDFProfileSettings AS EDFProfileSettings
		|WHERE
		|	EDFProfileSettings.EDExchangeMethod = Value(Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom)
		|	AND EDFProfileSettings.Company = &Company";
		Query.SetParameter("Company", ParticipantsSelection.Company);
		EDFProfileSettingsSelection = Query.Execute().Select();
		EDFProfileSettingsSelection.Next();
		EDFProfileSettings = EDFProfileSettingsSelection.Ref;
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	EDUsageAgreements.Ref AS EDFSetup,
		|	EDUsageAgreements.AgreementSetupExtendedMode AS ExtendedSettingMode,
		|	EDUsageAgreements.EDExchangeMethod AS EDExchangeMethod,
		|	EDUsageAgreements.CounterpartyID AS ID,
		|	EDUsageAgreements.ConnectionStatus
		|FROM
		|	Catalog.EDUsageAgreements AS EDUsageAgreements
		|WHERE
		|	Not EDUsageAgreements.DeletionMark
		|	AND EDUsageAgreements.Counterparty = &Counterparty
		|	AND EDUsageAgreements.Company = &Company";
		
		Query.SetParameter("Counterparty",  ParticipantsSelection.Participant);
		Query.SetParameter("Company", ParticipantsSelection.Company);
		SelectionSettings = Query.Execute().Select();
		
		If SelectionSettings.Next() Then
			EDFSetup = SelectionSettings.EDFSetup.GetObject();

			If Not SelectionSettings.ExtendedSettingMode
				AND SelectionSettings.EDExchangeMethod <> Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
				
				EDFSetup.AgreementSetupExtendedMode = True;
				
				SettingsProfileParameters = CommonUse.ObjectAttributesValues(EDFProfileSettings,
					"CompanyID, EDExchangeMethod");
				
			Else
				Filter = New Structure;
				Filter.Insert("EDFProfileSettings", EDFProfileSettings);
				FoundStrings = EDFSetup.OutgoingDocuments.FindRows(Filter);
				For Each String IN FoundStrings Do
					String.CounterpartyID = ParticipantsSelection.ID;
				EndDo;
			EndIf;
		Else
			EDFSetup = Catalogs.EDUsageAgreements.CreateItem();
			EDFSetup.Counterparty = ParticipantsSelection.Participant;
			EDFSetup.Description = String(ParticipantsSelection.Participant);
			
			EDFSetup.EDFProfileSettings = EDFProfileSettings;
			SettingsProfileParameters = CommonUse.ObjectAttributesValues(EDFProfileSettings,
			"Company, CompanyID, EDExchangeMethod, InvitationsTextTemplate, OutgoingDocuments");
			
			EDFSetup.Company                 = SettingsProfileParameters.Company;
			EDFSetup.EDExchangeMethod              = SettingsProfileParameters.EDExchangeMethod;
			EDFSetup.CompanyID    = SettingsProfileParameters.CompanyID;
			
			// Importing PM from the EDF settings profile.
			EDSourceTable = SettingsProfileParameters.OutgoingDocuments.Unload();
			EDSourceTable.Columns.Add("EDFProfileSettings");
			EDSourceTable.Columns.Add("EDExchangeMethod");
			EDSourceTable.Columns.Add("CompanyID");
			EDSourceTable.Columns.Add("CounterpartyID");
			
			EDSourceTable.FillValues(EDFProfileSettings,                                "EDFProfileSettings");
			EDSourceTable.FillValues(SettingsProfileParameters.EDExchangeMethod,           "EDExchangeMethod");
			EDSourceTable.FillValues(SettingsProfileParameters.CompanyID, "CompanyID");
			EDSourceTable.FillValues(ParticipantsSelection.ID,                   "CounterpartyID");
			
			EDFSetup.OutgoingDocuments.Load(EDSourceTable);
			
			For Each EnumValue IN Enums.EDExchangeFileFormats Do
				If EnumValue = Enums.EDExchangeFileFormats.CompoundFormat Then
					Continue;
				EndIf;
				RowArray = EDFSetup.ExchangeFilesFormats.FindRows(New Structure("FileFormat", EnumValue));
				If RowArray.Count() = 0 Then
					NewRow = EDFSetup.ExchangeFilesFormats.Add();
					NewRow.FileFormat  = EnumValue;
					// Default value for new
					If EnumValue = Enums.EDExchangeFileFormats.XML AND EDFSetup.Ref.IsEmpty() Then
						NewRow.Use = True;
					EndIf;
				EndIf;
			EndDo;
			
		EndIf;
		
		EDFSetup.CounterpartyID    = ParticipantsSelection.ID;
		EDFSetup.ConnectionStatus           = ParticipantsSelection.Status;
		
		AgreementState                      = Enums.EDAgreementStates.CoordinationExpected;
		If ParticipantsSelection.Status = Enums.EDExchangeMemberStatuses.Connected Then
			AgreementState = Enums.EDAgreementStates.Acts;
		ElsIf ParticipantsSelection.Status = Enums.EDExchangeMemberStatuses.Disconnected Then
			AgreementState = Enums.EDAgreementStates.Closed;
		EndIf;
		EDFSetup.AgreementState = AgreementState;
		
		EDFSetup.ErrorDescription = ParticipantsSelection.ErrorDescription;
		InfobaseUpdate.WriteObject(EDFSetup);

	EndDo;
	
	// Define and fill in the "EDFProfileSettings" and "EDFSetting" attributes in the electronic documents.
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDAttachedFiles.Ref AS ElectronicDocument,
	|	EDAttachedFiles.Counterparty,
	|	EDAttachedFiles.Company,
	|	EDUsageAgreementsOutgoingDocuments.Ref AS EDFSetup,
	|	EDUsageAgreementsOutgoingDocuments.EDFProfileSettings
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|		LEFT JOIN Catalog.EDUsageAgreements.OutgoingDocuments AS EDUsageAgreementsOutgoingDocuments
	|		ON EDAttachedFiles.Counterparty = EDUsageAgreementsOutgoingDocuments.Ref.Counterparty
	|			AND EDAttachedFiles.Company = EDUsageAgreementsOutgoingDocuments.EDFProfileSettings.Company
	|WHERE
	|	Not EDAttachedFiles.DeletionMark
	|	AND Not EDUsageAgreementsOutgoingDocuments.Ref.DeletionMark
	|	AND EDAttachedFiles.EDAgreement <> VALUE(Catalog.EDUsageAgreements.EmptyRef)
	|	AND (EDAttachedFiles.EDKind <> VALUE(Enum.EDKinds.PaymentOrder)
	|			OR EDAttachedFiles.EDKind <> VALUE(Enum.EDKinds.QueryStatement)
	|			OR EDAttachedFiles.EDKind <> VALUE(Enum.EDKinds.QueryNightStatements)
	|			OR EDAttachedFiles.EDKind <> VALUE(Enum.EDKinds.BankStatement))
	|
	|GROUP BY
	|	EDUsageAgreementsOutgoingDocuments.EDFProfileSettings,
	|	EDAttachedFiles.Ref,
	|	EDUsageAgreementsOutgoingDocuments.Ref,
	|	EDAttachedFiles.Counterparty,
	|	EDAttachedFiles.Company";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ElectronicDocument = Selection.ElectronicDocument.GetObject();
		ElectronicDocument.EDFProfileSettings = Selection.EDFProfileSettings;
		ElectronicDocument.EDAgreement       = Selection.EDFSetup;
		InfobaseUpdate.WriteObject(ElectronicDocument);
	EndDo;
	
	// Define and fill in the "EDFProfileSettings" and "EDFSetting" attributes in the incomplete ED packs.
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDPackage.Ref AS EDPackage,
	|	EDPackage.Sender,
	|	EDPackage.Recipient,
	|	EDPackage.EDFProfileSettings,
	|	EDPackage.Direction
	|FROM
	|	Document.EDPackage AS EDPackage
	|WHERE
	|	(EDPackage.PackageStatus = VALUE(Enum.EDPackagesStatuses.ToUnpacking)
	|			OR EDPackage.PackageStatus = VALUE(Enum.EDPackagesStatuses.PreparedToSending))
	|	AND Not EDPackage.DeletionMark";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If ValueIsFilled(Selection.Sender) AND ValueIsFilled(Selection.Recipient)
			AND Not ValueIsFilled(Selection.EDFProfileSettings) Then
			If Selection.Direction = Enums.EDDirections.Incoming Then
				
				EDFSettingParameters = ElectronicDocumentsService.GetEDExchangeSettingsByID(Selection.Recipient, Selection.Sender);
			ElsIf Selection.Direction = Enums.EDDirections.Outgoing Then
				
				EDFSettingParameters = ElectronicDocumentsService.GetEDExchangeSettingsByID(Selection.Sender, Selection.Recipient);
			EndIf;
			If EDFSettingParameters <> Undefined Then
				EDPackage = Selection.EDPackage.GetObject();
				EDPackage.EDFProfileSettings = EDFSettingParameters.EDFProfileSettings;
				EDPackage.EDFSetup       = EDFSettingParameters.EDFSetup;
				InfobaseUpdate.WriteObject(EDPackage);
			EndIf;
		EndIf;
	EndDo;
	
	CommitTransaction();
	
EndProcedure

// Handler of the
// EDL 1.2.4.4 update Transfers cryptography context settings to SSL object CreateDigitalSignaturesOnServer.
//
Procedure TransferCryptographyContextSettings() Export
	
	BeginTransaction();
	Try
		If Constants.UseDigitalSignatures.Get() = True Then
			WorkWithDSOnServer = Not (CommonUse.FileInfobase()
					OR CommonUseReUse.DataSeparationEnabled())
				AND (Constants.DeleteCryptographyContext.Get() = Enums.WorkContextsWithED.AtServer);
			ValueManager = Constants.CreateDigitalSignaturesAtServer.CreateValueManager();
			ValueManager.Value = WorkWithDSOnServer;
			InfobaseUpdate.WriteData(ValueManager);
			ValueManager = Constants.VerifyDigitalSignaturesAtServer.CreateValueManager();
			ValueManager.Value = WorkWithDSOnServer;
			InfobaseUpdate.WriteData(ValueManager);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure SaveSignedEDKinds(CertificatRef, SignedED)
	
	BeginTransaction();
	Try
		RecordSet = InformationRegisters.DigitallySignedEDKinds.CreateRecordSet();
		RecordSet.Filter.DSCertificate.Set(CertificatRef);
		RecordSet.Read();
		RecordSet.Load(SignedED);
		InfobaseUpdate.WriteData(RecordSet);
		CommitTransaction();
	Except
		RollbackTransaction();
	EndTry;
	
EndProcedure
