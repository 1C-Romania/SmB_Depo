////////////////////////////////////////////////////////////////////////////////
// Check one or several counterparties using FTS web service
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

#Region Checking

#Region CheckOneCounterparty

// Subscription to an event. Add to the TIN and KPP set register to check with reg job later
Procedure SaveCounterpartiesCheckResultOnWrite(CounterpartyObject, Cancel) Export 
	
	If CounterpartyObject.DataExchange.Load Then
		Return;
	EndIf;
	
	StorageAddress = Undefined;
	CounterpartyObject.AdditionalProperties.Property("StorageAddress", StorageAddress);
	SaveCounterpartiesCheckResult(CounterpartyObject, StorageAddress);
	
EndProcedure

Procedure SaveCounterpartiesCheckResult(CounterpartyObject, StorageAddress) Export 
	
	//Check conditions that do not require record in the register
	If Not CounterpartiesCheckServerCall.UseChecksAllowed() OR CounterpartyObject.IsFolder Then 
	 	Return;
	EndIf;
	
	// Get a reference instead of an object
	CounterpartyRef 	= CounterpartyObject.Ref;
	TIN 				= CounterpartyObject.TIN;
	KPP 				= CounterpartyObject.KPP;
	
	If ValueIsFilled(StorageAddress) AND IsTempStorageURL(StorageAddress) Then
		// This record with form opening 
		TransferCheckResultsFromStoragesInRegister(CounterpartyRef, TIN, KPP, StorageAddress);
	Else
		// You go to this branch if this is a counterparty record:
		// 1. without opening
		// 2 form. opening the form but the background job according to the counterparty state is not complete yet
		
		// If the counterparty is already written into the register,
		// do not write their StorageAddress into  the CurrentCounterpartyState function do not send as if you are in this branch, then the storage does not contain the required data
		CounterpartyState = CounterpartiesCheckServerCall.CurrentCounterpartyState(CounterpartyRef, TIN, KPP);
		If ValueIsFilled(CounterpartyState) Then 
		 	Return;
		EndIf;
		
		// Writing to the register is executed with an empty state State will be determined later by scheduled job
		WriteCounterpartyWithEmptyState(CounterpartyRef, TIN, KPP);
		
	EndIf;
		
EndProcedure

// Part of the background job on the counterparty check from the counterparty form
Procedure CheckCounterpartyBackgroundJob(Parameters) Export 
	
	// Assigning of a date is located here as CurrentSessionDate works only on server
	If Not Parameters.Property("Date") Then
		Parameters.Insert("Date", BegOfDay(CurrentSessionDate()));
	EndIf;
	
	Try
		CheckCounterparty(Parameters, Parameters.StorageAddress);
	Except
		
		ErrorInfo = ErrorInfo();
		WriteLogEvent(NStr("en = 'Check counterparties.Check counterparty from the counterparty card'"),
			EventLogLevel.Error,,,DetailErrorDescription(ErrorInfo));
			
	EndTry;
	
EndProcedure

// Check one counterparty by TIN, KPP and Date
Procedure CheckCounterparty(Parameters, StorageAddress = Undefined) Export 
	
	// Prepare data in the required format to transfer for check
	CounterpartiesData = EmptyTypedTablePattern();
	
	NewRow = CounterpartiesData.Add();
	NewRow.DataAreaAuxiliaryData = CommonUse.SessionSeparatorValue();
	FillPropertyValues(NewRow, Parameters);
	
	CounterpartiesCheck(CounterpartiesData, StorageAddress);
	
EndProcedure

#EndRegion

#Region CheckMultipleCounterparties

// For
// service model scheduled job
// updates the For local mode updates the stages and writes the missing TIN and KPP states
Procedure CounterpartiesCheckScheduledJob() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	// Check if the mechanism is enabled
	If Not CounterpartiesCheckEnabled() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	CounterpartiesStates.Counterparty,
	|	CounterpartiesStates.TIN,
	|	CounterpartiesStates.KPP,
	|	&Date AS Date,
	|	CounterpartiesStates.DataAreaAuxiliaryData AS DataAreaAuxiliaryData
	|FROM
	|	InformationRegister.CounterpartiesStates AS CounterpartiesStates
	|WHERE
	|	CounterpartiesStates.State <> VALUE(Enum.CounterpartyExistenceStates.ContainsErrorsInData)";

	// Specify date, by which the check should be run
	Query.SetParameter("Date", BegOfDay(CurrentSessionDate()));
	CounterpartiesData = Query.Execute().Unload();
	
	// Check only those TIN and KPP that were written to the register
	CounterpartiesCheck(CounterpartiesData);
	
	// Write missing TIN and KPP to the register in the local mode
	If Not CommonUseReUse.DataSeparationEnabled() Then
		CheckUncheckedCounterparties(False);
	EndIf;
	
EndProcedure

// Fills the register according to the Filling is in process counterparties catalog:
// 1. After manual checking launch with
// a background job 2. IN services mode - update of the IB in each field separately
Procedure CounterpartiesCheckAfterCheckInclusion(Parameters = Undefined) Export
	
	IsUpdateIBSaaS = False;
	PortionSize = 1000;
	
	If Parameters = Undefined Then
		// This filling of the register after enabling checkings
	Else
		// This is IB update.
		// Update should be run only in the service model
		If CommonUseReUse.DataSeparationEnabled() Then
			IsUpdateIBSaaS = True;
		Else
			Return;
		EndIf;
	EndIf;
	
	CheckUncheckedCounterparties(IsUpdateIBSaaS, Parameters);
	
EndProcedure

// Launches after checking the offer of connection or from the settings
Procedure CounterpartiesCheckAfterBackgroundJobCheckingSwitch() Export
	
	Try
	
		BackgroundJobs.Execute("CounterpartiesCheck.CounterpartiesCheckAfterCheckStart", 
		, "CheckAfterEnableMechanism", NStr("en = 'Check counterparties'"));

	Except
		
		// Exception appears when you try to run the background job until
		// the previous Special processing is not required background job was not finished
		
		ErrorInfo = ErrorInfo();
		WriteLogEvent(NStr("en = 'Check counterparties.Check counterparties in background job'"),
			EventLogLevel.Error,,,DetailErrorDescription(ErrorInfo));
			
	EndTry;
	
EndProcedure

Procedure DefineInactiveCounterparties(CheckedCounterparties) Export 
	
	// Prepare data to check it
	CounterpartiesData = CheckedCounterparties.Copy();
	AddColumnDataArea(CounterpartiesData);
	CounterpartiesData.FillValues(CommonUse.SessionSeparatorValue(), "DataAreaAuxiliaryData");
	
	// Delete an empty column from the source table
	If CheckedCounterparties.Columns.Find("Status") <> Undefined Then
		CheckedCounterparties.Columns.Delete("Status");
	EndIf;
	
	// Check FTS with a web service
	CounterpartiesCheck(CounterpartiesData,,False);
	
	Stages = CounterpartiesCheckClientServer.InactiveCounterpartyState(True, True);
	
	FillStates(CheckedCounterparties, CounterpartiesData, Stages);
	
EndProcedure

#EndRegion

#EndRegion

#Region VerificationSettings

// Set value to the UseCounterpartiesCheck constant 
Procedure SaveSettingsValues(UseService) Export
	
	// Set constant value 
	Constants.UseCounterpartiesVerification.Set(UseService);

EndProcedure

Function SettingsValues() Export
	
	// fill general settings
	UseService 	= Constants.UseCounterpartiesVerification.Get();
	ServiceAddress 		= "";
	
	Return New Structure("UseService, ServiceAddress", UseService, ServiceAddress);
	
EndFunction

// Update IB for services mode
Function EnableCounterpartiesCheckForServicesMode() Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		CounterpartiesCheck.SaveSettingsValues(True);
	EndIf;
	
EndFunction

Function CounterpartiesCheckEnabled() Export
	
	// Check if the service is enabled
	ServiceSettings = CounterpartiesCheck.SettingsValues();
	UseService = ServiceSettings.UseService;

	Return UseService;
	
EndFunction

Function HasRightOnCheckingUsage() Export
	
	Return CounterpartiesCheckOverridable.HasRightOnCheckingUsage();
	
EndFunction

Function HasRightOnSettingsEditing() Export
	
	Return CounterpartiesCheckOverridable.HasRightOnSettingsEditing();
	
EndFunction

Function ProxyService(ErrorDescription = "") Export
	
	WSProxy = Undefined;
	Try
	
		ServiceSettings = SettingsValues();
		ServiceAddress = ServiceSettings.ServiceAddress;
		
		If Not ValueIsFilled(ServiceAddress) Then
			ErrorDescription = NStr("en = 'Service address of data check service is not specified.'");
		Else
			WSProxy = GetWSProxy(ServiceAddress);
		EndIf;
		
	Except
		
		ErrorInfo = ErrorInfo();
		WriteLogEvent(NStr("en = 'Check counterparties.Error accessing the web service of counterparties checking'"),
			EventLogLevel.Error,,,DetailErrorDescription(ErrorInfo));
			
		ErrorDescription = ErrorInfo.Description;

	EndTry; 
	
	Return WSProxy;
	
EndFunction

Function HasAccessToFTSService() Export
	
	Proxy = ProxyService();
	Return Proxy <> Undefined;
	
EndFunction

Function DoNotShowAgainOfferToConnect() Export
	
	Return CommonSettingsStorage.Load("CounterpartiesCheck_CheckDoNotShowProposalToUseService") = True;
	
EndFunction

Procedure SaveDateLastLogInDisplayOffer() Export
	
	CommonSettingsStorage.Save("CounterpartiesCheck_LastDisplaySuggestionsForServiceInclusionDate", , CurrentSessionDate());
	
EndProcedure

#EndRegion

#Region Lables

Function WarningTextAboutServiceOperationTestMode() Export
	
	Return NStr("en = 'FTS web service is currently in the test mode'");
	
EndFunction

Procedure SetLablesInReportsPanelOnCreateAtServer(Form) Export
	
	RefForInstruction = New FormattedString(" ", CounterpartiesCheckClientServer.RefForInstruction());
	
	// All counterparties are correct
	FormItem = Form.Items.Find("TextOnCorrectCounterparties");
	If FormItem <> Undefined Then
		FormItem.Title = New FormattedString(NStr("en = 'Check of the counterparties according to FTS data is successful'"), RefForInstruction);
	EndIf;
	
	// There are incorrect counterparties
	FormItem = Form.Items.Find("TextOnBadCounterparties");
	If FormItem <> Undefined Then
		FormItem.Title = New FormattedString(NStr("en = 'Inactive counterparties were found according to FTS data.'"), RefForInstruction);
	EndIf;
	
	// Check is in progress
	FormItem = Form.Items.Find("TextOnCheckInProgress");
	If FormItem <> Undefined Then
		FormItem.Title = New FormattedString(NStr("en = 'Counterparties check is in progress according to FTS data'"), RefForInstruction);
	EndIf;
	
	// No access to web service
	FormItem = Form.Items.Find("TextNoAccessToService");
	If FormItem <> Undefined Then
		FormItem.Title = New FormattedString(NStr("en = 'Unable to check counterparties: FTS service is temporarily unavailable'"), RefForInstruction);
	EndIf;
	
EndProcedure

#EndRegion

#Region HelperProceduresAndFunctions

Procedure TransferCheckResultsFromStoragesInRegister(Val CounterpartyRef, TIN, KPP, StorageAddress) Export
	
	CounterpartiesData = GetFromTempStorage(StorageAddress);
	
	If Not ValueIsFilled(CounterpartiesData) Then
		WriteCounterpartyWithEmptyState(CounterpartyRef, TIN, KPP);
		Return;
	EndIf;
	
	CounterpartyData = CounterpartiesData[0];
	
	// Check if the data in the storage expired 
	If TIN = CounterpartyData.TIN AND KPP = CounterpartyData.KPP Then
		CounterpartyData.Counterparty = CounterpartyRef;
		// Transfer checking result from storage into register
		SaveCheckResultsInRegister(CounterpartiesData);
	Else
		WriteCounterpartyWithEmptyState(CounterpartyRef, TIN, KPP);
	EndIf;
	
EndProcedure

Function StorageAddressWithRestoredCounterpartyState(CounterpartyRef, TIN, KPP, UUID) Export
	
	Status = Enums.CounterpartyExistenceStates.EmptyRef();
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	               |	CounterpartiesStates.State,
	               |	CounterpartiesStates.TIN,
	               |	CounterpartiesStates.KPP,
	               |	CounterpartiesStates.DataAreaAuxiliaryData,
	               |	CounterpartiesStates.Counterparty
	               |FROM
	               |	InformationRegister.CounterpartiesStates AS CounterpartiesStates
	               |WHERE
	               |	CounterpartiesStates.Counterparty = &Counterparty
	               |	AND CounterpartiesStates.TIN = &TIN
	               |	AND CounterpartiesStates.KPP = &KPP";

	Query.SetParameter("TIN",		TIN);
	Query.SetParameter("KPP", 		KPP);
	Query.SetParameter("Counterparty", CounterpartyRef);
	
	QueryResult = Query.Execute().Select();
	
	// Determine state from register
	CounterpartiesData = EmptyTypedTablePattern();
	NewRow = CounterpartiesData.Add();

	If QueryResult.Next() Then
		FillPropertyValues(NewRow, QueryResult);
	Else
		NewRow.Counterparty 	= CounterpartyRef;
		NewRow.TIN 		= TIN;
		NewRow.KPP 		= KPP;
		NewRow.DataAreaAuxiliaryData = CommonUse.SessionSeparatorValue();
	EndIf;
	
	Return PutToTempStorage(CounterpartiesData, UUID);
		
EndFunction

Function EmptyTypedTablePattern() Export
	
	// Create table
	CounterpartiesData = New ValueTable;
	CounterpartiesData.Columns.Add("Counterparty", 	New TypeDescription("CatalogRef.Counterparties"));
	CounterpartiesData.Columns.Add("TIN", 			New TypeDescription("String",,New StringQualifiers(12)));
	CounterpartiesData.Columns.Add("KPP", 			New TypeDescription("String",,New StringQualifiers(9)));
	CounterpartiesData.Columns.Add("Date", 		New TypeDescription("Date",,,New DateQualifiers(DateFractions.Date)));
	CounterpartiesData.Columns.Add("Status", 	New TypeDescription("EnumRef.CounterpartyExistenceState"));
	
	AddColumnDataArea(CounterpartiesData);

	Return CounterpartiesData;
	
EndFunction

Procedure AddColumnDataArea(Table) Export
	
	Table.Columns.Add("DataAreaAuxiliaryData", 	New TypeDescription("Number", New NumberQualifiers(7, 0, AllowedSign.Nonnegative)));
	
EndProcedure

Procedure SaveCheckResultsToStorage(CounterpartiesData, StorageAddress = Undefined) Export
	
	// If the counterparty is new, then during changing of TIN and KPP you do not have a ref
	// and it is impossible to write in the register That is why save the result to the storage and transfer checking results to the register when the ref appears during the counterparty writing
	If CounterpartiesData.Count() = 1 AND ValueIsFilled(StorageAddress) Then
		PutToTempStorage(CounterpartiesData, StorageAddress);
	EndIf;
	
EndProcedure

#EndRegion

#Region CounterpartiesCheckInDocuments

Procedure CounterpartiesCheckInDocumentBackgroundJob(Form, Item = Undefined) Export
	
	// Render that checking is being executed
	CounterpartiesCheckOverridable.DrawCounterpartyInDocumentStates(Form, Enums.CounterpartiesCheckStates.CheckingInProgress, Item);
	
	// Fill data of checked counterparties
	CounterpartiesData = EmptyTypedTablePattern();
	CounterpartiesData.Columns.Add("ThisIsInvoice", New TypeDescription("Boolean"));
	CounterpartiesCheckOverridable.InitializeCheckedCounterpartiesData(Form, CounterpartiesData);
	
	If CounterpartiesData.Count() > 0 Then
		
		// Initialize background job parameters
		Form.CounterpartiesCheckResultAddress 		= PutToTempStorage(Undefined, Form.UUID);
		Form.CounterpartiesCheckJobID 	= Undefined;
		
		LaunchParameters = New Structure;
		LaunchParameters.Insert("CounterpartiesData", 					CounterpartiesData);
		LaunchParameters.Insert("CounterpartiesCheckResultAddress", 	Form.CounterpartiesCheckResultAddress);
		
		Parameters = New Array;
		Parameters.Add(LaunchParameters);
		
		Try
		 	BackgroundJob = BackgroundJobs.Execute("CounterpartiesCheck.CounterpartiesCheckInDocument", 
				Parameters, , NStr("en = 'Check counterparties in document'"));
				
			If BackgroundJob <> Undefined Then 
				Form.CounterpartiesCheckJobID = BackgroundJob.UUID;
			EndIf;
		Except
			
			// Exception appears when you try to run the background job until
			// the previous Special processing is not required background job was not finished
			ErrorInfo = ErrorInfo();
			WriteLogEvent(NStr("en = 'Check counterparties.Counterparties check as a background job in the document'"),
				EventLogLevel.Error,,,DetailErrorDescription(ErrorInfo));
				
		EndTry;
			
	EndIf;
	
EndProcedure

Function CounterpartiesCheckResultInDocument(Form) Export
	
	CheckResult = Enums.CounterpartiesCheckStates.CheckingExecuted;
	
	If ValueIsFilled(Form.CounterpartiesCheckResultAddress) AND 
		IsTempStorageURL(Form.CounterpartiesCheckResultAddress) Then
		BackgroundJobWorkResult = GetFromTempStorage(Form.CounterpartiesCheckResultAddress);
		
		If BackgroundJobWorkResult <> Undefined Then
			If BackgroundJobWorkResult.Property("NoAccessToWebServiceFTS") Then
				// No access to web service
				CheckResult = Enums.CounterpartiesCheckStates.AccessDeniedToWebService;
			Else
				CheckResult = Enums.CounterpartiesCheckStates.CheckingExecuted;
				
				// Background job finished work
				CounterpartiesData = BackgroundJobWorkResult.CounterpartiesData;
				CounterpartiesCheckOverridable.RememberCounterpartiesCheckResult(Form, CounterpartiesData);
				CounterpartiesCheckOverridable.DefineCurrentErrorValues(Form);
				
			EndIf;
			
			// Clear this address of jobs in all rows
			Form.CounterpartiesCheckResultAddress = "";
			
		EndIf;
		
	EndIf;
	
	Return CheckResult;
	
EndFunction

Function InCustomerInvoiceNoteFilledAtLeastOneCounterparty(CustomerInvoiceNote) Export
	
	FilledAtLeastOneCounterparty = False;
	CounterpartiesCheckOverridable.DefineAtLeastOneCounterpartyInCustomerInvoiceNotePresence(CustomerInvoiceNote, FilledAtLeastOneCounterparty);
	
	Return FilledAtLeastOneCounterparty;
	
EndFunction

Function InCustomerInvoiceNoteChangedAtLeastOneCounterparty(NewCustomerInvoiceNote, AddressOfPreviousAccountsInvoice) Export
	
	PreviousCustomerInvoiceNote = GetFromTempStorage(AddressOfPreviousAccountsInvoice);
	
	CounterpartiesChanged = False;
	CounterpartiesCheckOverridable.CheckChangeCounterpartiesInCustomerInvoiceNote(
		NewCustomerInvoiceNote, PreviousCustomerInvoiceNote, CounterpartiesChanged);
		
	Return CounterpartiesChanged;
	
EndFunction

 
#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

#Region Checking

// Check multiple counterparties
Procedure CounterpartiesCheck(CounterpartiesData, StorageAddress = Undefined, IsCounterpartiesCatalogCheck = True)
	
	// If there is no access to web service, check is not executed
	If Not CounterpartiesCheck.HasAccessToFTSService() Then
		Return;
	EndIf;
	
	// If by some counterparties you can determine that they do not exist without referring to the service, then do not refer to thee service
	If IsCounterpartiesCatalogCheck Then
		GetCounterpartiesStatesFromCache(CounterpartiesData);
	EndIf;
	
	// Convert data into the required format, find records with errors 
	PrepareDataToCheck(CounterpartiesData);
	
	// Receive the checking results
	// from the web service Check only those counterparties that have undefined state of existance and do not have errors
	Filter = New Structure();
	Filter.Insert("Status", Enums.CounterpartyExistenceStates.EmptyRef());
	GetCheckResultWebService(CounterpartiesData, Filter);
	
	If IsCounterpartiesCatalogCheck Then
		If ValueIsFilled(StorageAddress) Then
			SaveCheckResultsToStorage(CounterpartiesData, StorageAddress);
		Else
			SaveCheckResultsInRegister(CounterpartiesData);
		EndIf;
	EndIf;
		
EndProcedure

Procedure CounterpartiesCheckInDocument(Parameters) Export
	
	CheckedCounterparties 	= Parameters.CounterpartiesData;
	StorageAddress 			= Parameters.CounterpartiesCheckResultAddress;
	
	// If there is no access to web service, check is not executed
	If CounterpartiesCheck.HasAccessToFTSService() Then
		
		CounterpartiesData = CheckedCounterparties.Copy();
		CounterpartiesCheck(CounterpartiesData, StorageAddress, False);
		
		FillStates(CheckedCounterparties, CounterpartiesData);
		
		Result = New Structure;
		Result.Insert("CounterpartiesData", CheckedCounterparties);
	Else
		Result = New Structure;
		Result.Insert("NoAccessToWebServiceFTS", True);
	EndIf;
	
	PutToTempStorage(Result, StorageAddress);
	
EndProcedure

#EndRegion

#Region WriteInInformationRegister

Procedure SaveCheckResultsInRegister(CounterpartiesData)
	
	For Each CounterpartyData IN CounterpartiesData Do
		
		If Not ValueIsFilled(CounterpartyData.TIN) Then
			Continue;
		EndIf;
		
		BeginTransaction();
		
		Try
			
			Counterparty							= CounterpartyData.Counterparty;
			DataAreaAuxiliaryData	= CounterpartyData.DataAreaAuxiliaryData;
			
			// Lock by the Counterparty
			KeyStructure = New Structure("Counterparty, DataAreaAuxiliaryData", Counterparty, DataAreaAuxiliaryData);
			Key = InformationRegisters.CounterpartiesStates.CreateRecordKey(KeyStructure);
			LockDataForEdit(Key);
			
			Block = New DataLock;
			LockItem = Block.Add("InformationRegister.CounterpartiesStates");
			LockItem.SetValue("Counterparty", Counterparty);
			LockItem.SetValue("DataAreaAuxiliaryData", DataAreaAuxiliaryData);
			Block.Lock();
			
			// Write data to the register
			RecordSet = InformationRegisters.CounterpartiesStates.CreateRecordSet();
			RecordSet.Filter.Counterparty.Set(Counterparty);
			RecordSet.Filter.DataAreaAuxiliaryData.Set(DataAreaAuxiliaryData);
			RecordSet.Clear();
			
			Record = RecordSet.Add();
			FillPropertyValues(Record, CounterpartyData); 
			
			RecordSet.Write(True);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorInfo = ErrorInfo();
			
			WriteLogEvent(
			NStr("en = 'Check counterparties. Write counterparties checking results to the register'"), 
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo));
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure WriteCounterpartyWithEmptyState(CounterpartyRef, TIN, KPP) 
	
	// Form data to record in the register
	CounterpartiesData = EmptyTypedTablePattern();
	
	NewRow = CounterpartiesData.Add();
	NewRow.Counterparty 	= CounterpartyRef;
	NewRow.TIN 		= TIN;
	NewRow.KPP 		= KPP;
	NewRow.DataAreaAuxiliaryData = CommonUse.SessionSeparatorValue();
	
	SaveCheckResultsInRegister(CounterpartiesData);
		
EndProcedure

#EndRegion

#Region WorkWithWebService

Procedure GetCheckResultWebService(CounterpartiesData, Filter) Export
	
	// Check only those counterparties that correspond to the specified selection
	CounterpartiesDataToCheckWithService = CounterpartiesData.FindRows(Filter);
	CounterpartiesQuantity = CounterpartiesDataToCheckWithService.Count();

	If CounterpartiesQuantity = 0 Then
		// No data to check
		Return;
	EndIf;
	
	If Not CounterpartiesCheck.HasAccessToFTSService() Then
		// No access to web service.
		Return;
	EndIf;
	
	Proxy = CounterpartiesCheck.ProxyService();
	
	TargetNamespace = "";
	
	PortionSize = 10000;
	
	// Divide the entire table into queries blocks 
	QueryQuantity = ?(CounterpartiesQuantity % PortionSize = 0, CounterpartiesQuantity / PortionSize, Int(CounterpartiesQuantity / PortionSize) + 1);
		
	// Perform some queries. Each query has no more than 10,000 rows
	For PortionNumber = 1 To QueryQuantity Do 
		
		MinimumCounterpartyNumber 	= min(PortionSize * (PortionNumber - 1), CounterpartiesQuantity);
		MaxCounterpartyNumber 	= min(PortionSize * PortionNumber, CounterpartiesQuantity) - 1;

		WSQuery = Proxy.XDTOFactory.Create(Proxy.XDTOFactory.Type(TargetNamespace, "NdsRequest"));
		
		For CurrentCounterpartyIndex = MinimumCounterpartyNumber To MaxCounterpartyNumber Do
			
			CounterpartyData = CounterpartiesDataToCheckWithService[CurrentCounterpartyIndex];
			AddCounterpartyInQueryService(WSQuery, Proxy, TargetNamespace, CounterpartyData); 
			
		EndDo;
		
		If WSQuery.NP.Count() = 0 Then
			Continue;
		EndIf;
		
		// Get checking result from service
		NdsResponse = Proxy.NdsRequest(WSQuery);
		ProcessServiceResponse(NdsResponse, CounterpartiesDataToCheckWithService, MinimumCounterpartyNumber, MaxCounterpartyNumber);
		
	EndDo; 
	
EndProcedure

Procedure AddCounterpartyInQueryService(WSQuery, Proxy, TargetNamespace, CounterpartyData)
	
	Try
	
		WSCounterparty = Proxy.XDTOFactory.Create(Proxy.XDTOFactory.Type(TargetNamespace, "NdsRequest_NP"));
	
		// Specify TIN, KPP and Date
		WSCounterparty.TIN = CounterpartyData.TIN;
		If ValueIsFilled(CounterpartyData.KPP) Then
			WSCounterparty.KPP = CounterpartyData.KPP;
		EndIf;
		If ValueIsFilled(CounterpartyData.Date)Then
			WSCounterparty.DT = DateString(CounterpartyData.Date);
		EndIf;
		
		// Add data by counterparty in the checking list
		WSQuery.NP.Add(WSCounterparty);

	Except
		
		ErrorInfo = ErrorInfo();
		
		CounterpartyData.Status = Enums.CounterpartyExistenceStates.ContainsErrorsInData;
		
		WriteLogEvent(NStr("en = 'Check counterparties.Create data to call the FTS web service'"),
			EventLogLevel.Error,,,DetailErrorDescription(ErrorInfo));
	EndTry; 
				
EndProcedure

Procedure ProcessServiceResponse(NdsResponse, CounterpartiesDataToCheckWithService, MinimumCounterpartyNumber, MaxCounterpartyNumber)
	
	CurrentResponseIndex = 0;
	For CurrentCounterpartyIndex = MinimumCounterpartyNumber To MaxCounterpartyNumber Do 
		CounterpartyData = CounterpartiesDataToCheckWithService[CurrentCounterpartyIndex];
		If CounterpartyData.Status <> Enums.CounterpartyExistenceStates.ContainsErrorsInData Then
			
			Try

				// Service response
				ResponseByCounterparty 			= NdsResponse.NP[CurrentResponseIndex];
				StateInResponse 			= ResponseByCounterparty.State;
				CounterpartyData.Status	= StateBasedOnServiceResponse(CounterpartyData, StateInResponse);
				
			Except
		
				RollbackTransaction();
				
				ErrorInfo = ErrorInfo();
				
				WriteLogEvent(
				NStr("en = 'Check counterparties.Web service response processing'"), 
				EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo));
			
			EndTry;
			
			CurrentResponseIndex = CurrentResponseIndex + 1;
		EndIf;
		
	EndDo;
				
EndProcedure

#Region WebServiceSettings

Function GetWSProxy(ServiceAddress) 
	
	WSProxy = CommonUse.WSProxy(
			WSDLAddress(ServiceAddress),
			"http://ws.unisoft",
			"FTSNDSCAWS",
			"FTSNDSCAWS_Port",
			Undefined,
			Undefined,
			30);
		
	Return WSProxy;
	
EndFunction

Function WSDLAddress(URI)
	
	Address = TrimAll(URI);
	If Find(Lower(Address), "?wsdl") = StrLen(Address) - 4 Then
		Return Address;
	Else
		Return Address + "?wsdl";
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#Region HelperProceduresAndFunctions

// Check errors, delete duplicates
Procedure PrepareDataToCheck(CounterpartiesDataToCheck)
	
	// Create table
	CounterpartiesData = EmptyTypedTablePattern();
	
	// Copy table keeping the columns types
	For Each CounterpartyDataToCheck IN CounterpartiesDataToCheck Do
		// Copy data from the table with raw data to the table with typed columns
		CounterpartyData = CounterpartiesData.Add();
		FillPropertyValues(CounterpartyData, CounterpartyDataToCheck, "Counterparty, TIN, KPP, State, Date, DataAreaAuxiliaryData");
		
		If CounterpartyData.Status <> Enums.CounterpartyExistenceStates.ContainsErrorsInData Then
			// Check errors, convert data into required format
			PrepareDataToCheckForEachCounterparty(CounterpartyData);
		EndIf;
	EndDo;
	
	// Delete duplicates from the table.
	CounterpartiesData.GroupBy("Counterparty, TIN, KPP, Date, State, DataAreaAuxiliaryData");
	
	CounterpartiesDataToCheck = CounterpartiesData;
	
EndProcedure

// Check errors by one counterparty
Procedure PrepareDataToCheckForEachCounterparty(CounterpartyData)
	
	Error = "";
	
	// Country
	// Check only Russian counterparties
	If Metadata.Catalogs.Counterparties.Attributes.Find("RegistrationCountry") <> Undefined Then
		RegistrationCountry = CounterpartyData.Counterparty.RegistrationCountry;
		If RegistrationCountry <> Catalogs.WorldCountries.Russia 
			AND RegistrationCountry <> Catalogs.WorldCountries.EmptyRef() Then
			CounterpartyData.Status = Enums.CounterpartyExistenceStates.NotBeChecked;
			Return;
		EndIf;
	EndIf;
	
	// ThisIsLegalEntity
	If StrLen(TrimAll(CounterpartyData.TIN)) = 10 AND StrLen(TrimAll(CounterpartyData.KPP)) = 9 Then
		ThisIsLegalEntity = True;
	ElsIf StrLen(TrimAll(CounterpartyData.TIN)) = 12 AND StrLen(TrimAll(CounterpartyData.KPP)) = 0 Then
		ThisIsLegalEntity = False;
	Else
		CounterpartyData.Status = Enums.CounterpartyExistenceStates.ContainsErrorsInData;
		Return;
	EndIf;
	
	// Date
	If Not ValueIsFilled(CounterpartyData.Date) Then
		CounterpartyData.Date = BegOfDay(CurrentSessionDate());
	EndIf;
	
	// TIN
	CounterpartyData.TIN = TrimAll(CounterpartyData.TIN);
	TIN = CounterpartyData.TIN;
	TINMeetsTheRequirements = RegulatedDataClientServer.TINMeetsTheRequirements(TIN, ThisIsLegalEntity, Error);
	If Left(TIN, 2) = "00" OR Not TINMeetsTheRequirements Then
		CounterpartyData.Status = Enums.CounterpartyExistenceStates.ContainsErrorsInData;
		Return;
	EndIf;
	
	// KPP
	If ThisIsLegalEntity Then
		CounterpartyData.KPP = TrimAll(CounterpartyData.KPP);
		KPP = CounterpartyData.KPP;
		KPPMeetsTheRequirements = RegulatedDataClientServer.KPPMeetsTheRequirements(KPP, Error);
		If Not KPPMeetsTheRequirements Then
			CounterpartyData.Status = Enums.CounterpartyExistenceStates.ContainsErrorsInData;
			Return;
		EndIf;
	EndIf;
	
EndProcedure

Procedure GetCounterpartiesStatesFromCache(CounterpartiesData)
	
	Query = New Query;
	Query.Text ="SELECT ALLOWED
	              |	CounterpartiesData.Counterparty,
	              |	CounterpartiesData.TIN,
	              |	CounterpartiesData.KPP,
	              |	CounterpartiesData.Date,
	              |	CounterpartiesData.DataAreaAuxiliaryData
	              |INTO CounterpartiesData
	              |FROM
	              |	&CounterpartiesData AS CounterpartiesData
	              |;
	              |
	              |////////////////////////////////////////////////////////////////////////////////
	              |SELECT ALLOWED
	              |	CounterpartiesData.Counterparty,
	              |	CounterpartiesData.TIN,
	              |	CounterpartiesData.KPP,
	              |	CounterpartiesData.Date,
	              |	CASE
	              |		WHEN CounterpartiesStates.State = VALUE(Enum.CounterpartyExistenceStates.ContainsErrorsInData)
	              |			THEN VALUE(Enum.CounterpartyExistenceStates.ContainsErrorsInData)
	              |		ELSE VALUE(Enum.CounterpartyExistenceStates.EmptyRef)
	              |	END AS Status,
	              |	CounterpartiesData.DataAreaAuxiliaryData
	              |FROM
	              |	CounterpartiesData AS CounterpartiesData
	              |		LEFT JOIN InformationRegister.CounterpartiesStates AS CounterpartiesStates
	              |		ON CounterpartiesData.Counterparty = CounterpartiesStates.Counterparty
	              |			AND CounterpartiesData.TIN = CounterpartiesStates.TIN
	              |			AND CounterpartiesData.KPP = CounterpartiesStates.KPP
	              |			AND CounterpartiesData.DataAreaAuxiliaryData = CounterpartiesStates.DataAreaAuxiliaryData";
	
	Query.SetParameter("CounterpartiesData", CounterpartiesData);
	CounterpartiesData = Query.Execute().Unload();
	
EndProcedure

Function DateString(Date)
	
	Result = Undefined;
	If TypeOf(Date) = Type("String") Then 
		// Date already in the right format in form rows
		Result = Date;
	ElsIf TypeOf(Date) = Type("Date") Then 
		Result = Format(Date, "DF=dd.MM.yyyy");
	EndIf;
	
	Return Result;
	
EndFunction

Function StateBasedOnServiceResponse(CounterpartyData, Response)
	
	If Response = "0" Then
		Status = Enums.CounterpartyExistenceStates.Acts;
	ElsIf Response = "1" Then
		Status = Enums.CounterpartyExistenceStates.ActivitiesDissolved;
	ElsIf Response = "3" Then
		Status = Enums.CounterpartyExistenceStates.KKPDoesNotMeetTIN;
	ElsIf Response = "4" Then
		Status = Enums.CounterpartyExistenceStates.NotAvailableInRegistry;
	EndIf;
		
	Return Status;
	
EndFunction

Procedure CheckUncheckedCounterparties(IsUpdateIBSaaS, Parameters = Undefined)
	
	// Select counterparties that are not in the information register and do not have TIN filled
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Counterparties.Ref AS Counterparty,
		|	Counterparties.TIN,
		|	Counterparties.KPP,
		|	&Date AS Date,
		|	&DataAreaAuxiliaryData AS DataAreaAuxiliaryData
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|		LEFT JOIN InformationRegister.CounterpartiesStates AS CounterpartiesStates
		|		ON Counterparties.Ref = CounterpartiesStates.Counterparty
		|WHERE
		|	(CounterpartiesStates.State IS NULL 
		|	OR CounterpartiesStates.State = VALUE(Enum.CounterpartyExistenceStates.EmptyRef))
		|	AND Counterparties.TIN <> """"
		|	AND Counterparties.IsFolder = FALSE";
		
	If IsUpdateIBSaaS Then
		PortionSize = 1000;
		Query.Text = StrReplace(Query.Text, "DISTINCT", "DISTINCT TOP "+ Format(PortionSize, "NG=0"));
	EndIf;

	Query.SetParameter("DataAreaAuxiliaryData", CommonUse.SessionSeparatorValue());
	Query.SetParameter("Date", BegOfDay(CurrentSessionDate()));
	CounterpartiesData = Query.Execute().Unload();
	
	// Abort update if there is no unprocessed data left
	If IsUpdateIBSaaS Then
		Parameters.DataProcessorCompleted = CounterpartiesData.Count() = 0;
		If Parameters.DataProcessorCompleted Then
			Return;
		EndIf;
	EndIf;
	
	CounterpartiesCheck(CounterpartiesData);
	
EndProcedure

Procedure FillStates(CheckedCounterparties, CounterpartiesData, Stages = Undefined)
	
	// Match checking results to the source table.
	Query = New Query;
	If CheckedCounterparties.Columns.Find("Status") <> Undefined Then
		CheckedCounterparties.Columns.Delete("Status");
	EndIf;
	PlaceValuesTableIntoTemporaryTable(CheckedCounterparties, Query, "CheckedCounterparties");
		
	PlaceValuesTableIntoTemporaryTable(CounterpartiesData, 	Query, "CounterpartiesData");
	
	// Define the Leave
	// only counterparties with errors in the table state by all counterparties
	Query.Text = Query.Text + "
		|SELECT 
		| 	" + ColumnsPresentation(CheckedCounterparties, "CheckedCounterparties.") + ", 
		| 	CounterpartiesData.State AS State
		|FROM CheckedCounterparties
		|AS CheckedCounterparties
		|LEFT JOIN CounterpartiesData AS CounterpartiesData
		|BY CheckedCounterparties.Counterparty = CounterpartiesData.Counterparty
		|AND CheckedCounterparties.TIN = CounterpartiesData.TIN
		|AND CheckedCounterparties.TIN =
		|CounterpartiesData.TIN AND (BEGINOFPERIOD(CheckedCounterparties.Data, Day) = BEGINOFPERIOD(CounterpartiesData.Date,Day)
		|		OR BEGINOFPERIOD(CheckedCounterparties.Data, Day) = DateTime(1,1,1))";
		
	If Stages <> Undefined Then
		Query.Text = Query.Text + "
			|
			|WHERE
			|	CounterpartiesData.State IN (&States)";
		
		Query.SetParameter("Stages", Stages);
	EndIf;
		
	CheckedCounterparties = Query.Execute().Unload();
	
EndProcedure

Procedure PlaceValuesTableIntoTemporaryTable(Table, Query, NameOfTemporaryTable)
	
	ColumnsPresentation = ColumnsPresentation(Table);
	
	Query.Text = Query.Text + "
		|SELECT 
		| " + ColumnsPresentation + "
		| INTO " + NameOfTemporaryTable + "
		| FROM &" + NameOfTemporaryTable + " AS " + NameOfTemporaryTable + ";
		|//////////////////////////////////////////////////////////////////////////////////////////////////";
	
	Query.SetParameter(NameOfTemporaryTable, Table);
	
EndProcedure

Function ColumnsPresentation(Table, TableSynonym = "")
	
	SourceTableColumns = New Array;
	For Each Column IN Table.Columns Do
		SourceTableColumns.Add(TableSynonym + Column.Name);
	EndDo;
	
	ColumnsPresentation = StringFunctionsClientServer.RowFromArraySubrows(SourceTableColumns, "," + Chars.LF);
	Return ColumnsPresentation;
	
EndFunction

#EndRegion

#EndRegion