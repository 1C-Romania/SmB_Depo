////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// For internal use only
Function EDFProfileSettingsIsUnique() Export
	
	If DeletionMark Then
		Return True;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	EDFProfileSettings.Ref AS EDFProfileSettings
	|FROM
	|	Catalog.EDFProfileSettings AS EDFProfileSettings
	|WHERE
	|	EDFProfileSettings.ref <> &Ref
	|	AND EDFProfileSettings.EDExchangeMethod = &EDExchangeMethod
	|			AND EDFProfileSettings.Company = &Company
	|					AND EDFProfileSettings.CompanyID = &CompanyID
	|	AND Not EDFProfileSettings.DeletionMark";
	
	Query.SetParameter("CompanyID", ThisObject.CompanyID);
	Query.SetParameter("Company",              ThisObject.Company);
	Query.SetParameter("Ref",                   ThisObject.Ref);
	Query.SetParameter("EDExchangeMethod",           ThisObject.EDExchangeMethod);
	Result = Query.Execute();
	CurrentSettingsProfileIsUnique = Result.IsEmpty();
	
	If Not CurrentSettingsProfileIsUnique Then
		MessagePattern = NStr("en = 'Infobase already contains a settings profile
		|with details: Company
		|- %1; Company ID
		|- %2; Exchange method - %3;'");
		Selection = Result.Select();
		Selection.Next();
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
														MessagePattern,
														ThisObject.Company,
														ThisObject.CompanyID,
														ThisObject.EDExchangeMethod);
		CommonUseClientServer.MessageToUser(ErrorText);
	EndIf;
	
	Return CurrentSettingsProfileIsUnique;
	
EndFunction

// For internal use only
Procedure MarkToDeleteAssociatedEDFSettings(EDFProfileSettings, Cancel) Export
	
	// Table part replacement in associated EDF settings.
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreements.CounterpartyID,
	|	EDUsageAgreements.Ref AS EDFSetup
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	Not EDUsageAgreements.AgreementSetupExtendedMode
	|	AND EDUsageAgreements.DeletionMark = &DeletionMark
	|	AND EDUsageAgreements.EDFProfileSettings = &EDFProfileSettings";
	
	Query.SetParameter("EDFProfileSettings", EDFProfileSettings.Ref);
	Query.SetParameter("DeletionMark",    Ref.DeletionMark);
	
	BeginTransaction();
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.EDUsageAgreements");
		LockItem.SetValue("Ref", Selection.EDFSetup);
		Block.Lock();
		
		// Preparing for a onetime PM replacement in EDF settings.
		EDSourceTable = EDFProfileSettings.OutgoingDocuments.Unload();
		EDSourceTable.Columns.Add("EDFProfileSettings");
		EDSourceTable.Columns.Add("EDExchangeMethod");
		EDSourceTable.Columns.Add("CompanyID");
		EDSourceTable.Columns.Add("CounterpartyID");
		
		EDSourceTable.FillValues(EDFProfileSettings.Ref,                   "EDFProfileSettings");
		EDSourceTable.FillValues(EDFProfileSettings.EDExchangeMethod,           "EDExchangeMethod");
		EDSourceTable.FillValues(EDFProfileSettings.CompanyID, "CompanyID");
		EDSourceTable.FillValues(Selection.CounterpartyID,            "CounterpartyID");
		
		SelectedEDFSetup = Selection.EDFSetup.GetObject();
		SelectedEDFSetup.DataExchange.Load = True;
		SelectedEDFSetup.DeletionMark = DeletionMark;
		SelectedEDFSetup.CompanyID = EDFProfileSettings.CompanyID;
		SelectedEDFSetup.OutgoingDocuments.Load(EDSourceTable);
		SelectedEDFSetup.Write();
		
	EndDo;
	
	CommitTransaction();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DeletionMark Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Company) Then
		CommonUseClientServer.MessageToUser(
			ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Company"),
			ThisObject,
			"Company",
			,
			Cancel);
	EndIf;

	If EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom Then
		If CompanySignatureCertificates.Count() = 0 Then
			CommonUseClientServer.MessageToUser(
				ElectronicDocumentsClientServer.GetMessageText("List", "Filling", , , "Certificates of company"),
				ThisObject,
				"CompanySignatureCertificates",
				,
				Cancel);
		EndIf;
		
		Return;
	Else
		Filter = New Structure;
		Filter.Insert("UseDS", True);
		
		If OutgoingDocuments.FindRows(Filter).Count() > 0 AND CompanySignatureCertificates.Count() = 0 Then
			CommonUseClientServer.MessageToUser(
				ElectronicDocumentsClientServer.GetMessageText("List", "Filling", , , "Certificates of company"),
				ThisObject,
				"CompanySignatureCertificates",
				,
				Cancel);
		EndIf;
		
		Return;
	EndIf;
	
	If EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP Then
		If Not ValueIsFilled(ServerAddress) Then
			CommonUseClientServer.MessageToUser(
				ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Server address"),
				ThisObject,
				"ServerAddress",
				,
				Cancel);
		EndIf;
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Ref.DeletionMark <> DeletionMark Then
		MarkToDeleteAssociatedEDFSettings(ThisObject, Cancel)
	EndIf;

EndProcedure





