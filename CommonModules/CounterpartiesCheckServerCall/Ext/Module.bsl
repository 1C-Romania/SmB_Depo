////////////////////////////////////////////////////////////////////////////////
// Check counterparties: launch checks, save settings
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Starts when editing attributes inside of the counterparty card
Procedure CheckCounterpartyOnChange(LaunchParameters) Export  
	
	Try
	
		Parameters = New Array;
		Parameters.Add(LaunchParameters);
		
		BackgroundJobs.Execute("CounterpartiesCheck.CheckCounterpartyBackgroundJob", 
			Parameters, LaunchParameters.TIN + " " + LaunchParameters.KPP, NStr("en='Check counterparty ';ru='Проверка контрагента '"));
	
	Except
		
		// Exception appears in case of background job with the
		// same key Special processing is not required
			
		ErrorInfo = ErrorInfo();
		WriteLogEvent(NStr("en='Check counterparties.Check counterparty in the background job';ru='Проверка контрагентов.Проверка контрагента в фоновом задании'"),
			EventLogLevel.Error,,,DetailErrorDescription(ErrorInfo));
			
	EndTry;
	
EndProcedure

// Clear cache
Function ClearSavedCounterpartiesCheckResults() Export 
	
	BeginTransaction();
	
	Try
	
		Query = New Query;
		Query.Text = 
			"SELECT ALLOWED DISTINCT
			|	CounterpartiesStates.Counterparty,
			|	VALUE(Enum.CounterpartyExistenceStates.EmptyRef) AS Status,
			|	CounterpartiesStates.TIN,
			|	CounterpartiesStates.KPP,
			|	CounterpartiesStates.DataAreaAuxiliaryData
			|FROM
			|	InformationRegister.CounterpartiesStates AS CounterpartiesStates";

		CounterpartiesData = Query.Execute().Unload();
		
	 	RecordSet = InformationRegisters.CounterpartiesStates.CreateRecordSet();
		RecordSet.Load(CounterpartiesData);
		RecordSet.Write();
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		WriteLogEvent(
		NStr("en='Check counterparties.Clear previous check results';ru='Проверка контрагентов.Очистка предыдущих результатов проверок'"), 
		EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
		
	EndTry;
	
EndFunction

#Region CounterpartyStateDefinition

// Defines according to record in the information register
Function CounterpartyExists(CounterpartyRef, TIN, KPP) Export
	
	CounterpartyExists = True;
	
	// Define if the service is enabled 
	UseChecksAllowed = CounterpartiesCheckServerCall.UseChecksAllowed();
	If UseChecksAllowed Then
		
		// Receive counterparty state from the information register
		Status = CurrentCounterpartyState(CounterpartyRef, TIN, KPP);
		
		// Define by the state if counterparty exists
		CounterpartyExists = CounterpartiesCheckClientServer.IsActiveCounterpartyState(Status);

	Else
		CounterpartyExists = True;
	EndIf;
	
	Return CounterpartyExists;
	
EndFunction

// Receives counterparty state from the information register
Function CurrentCounterpartyState(CounterpartyRef, TIN, KPP, StorageAddress = Undefined) Export
	
	Status = Enums.CounterpartyExistenceStates.EmptyRef();
	
	// 1. Try to receive counterparty state from the storage 
	If ValueIsFilled(StorageAddress) AND IsTempStorageURL(StorageAddress) Then
		
		CounterpartyData = GetFromTempStorage(StorageAddress);
		
		If CounterpartyData <> Undefined Then
			If CounterpartyData.Count() > 0 Then
				Status = CounterpartyData[0].Status;
			EndIf;
		EndIf;
			
	EndIf;
		
	// 2. If there is no result in storage, try to receive a state from register
	If Not ValueIsFilled(Status) AND ValueIsFilled(CounterpartyRef) Then
		
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		               |	CounterpartiesStates.State
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
		While QueryResult.Next() Do
			Status = QueryResult.Status;
		EndDo;
		
	EndIf;
	
	Return Status;
		
EndFunction

Function CounterpartiesCheckEnded(CounterpartiesCheckJobID) Export
	
	BackgroundJobExists = BackgroundJobs.FindByUUID(CounterpartiesCheckJobID) <> Undefined;
	If BackgroundJobExists Then 
		Return LongActions.JobCompleted(CounterpartiesCheckJobID); 
	Else
		Return True; 
	EndIf;
EndFunction

#EndRegion

#Region VerificationSettings

Procedure RememberThatNoNeedToShowOfferToUseService() Export
	
	CommonSettingsStorage.Save("CounterpartiesCheck_CheckDoNotShowProposalToUseService", , True);
	
EndProcedure

// Defines if an offer to enable check taking into account the next one needs to be shown:
// 1. That there is rights to use
// or set check 2. That check is not
// enabled 3. That user did not click
// the DoNotShow button 4. That from the time an offer was displayed last time a definite period of time passed
Function RequiredToShowOfferDisableCounterpartiesCheck() Export
	
	RequiredToShowOffer =
		// Do not show offer in the service model
		Not CommonUseReUse.DataSeparationEnabled()
		// Check if the rights exist
		AND (CounterpartiesCheck.HasRightOnCheckingUsage() 
		OR CounterpartiesCheck.HasRightOnSettingsEditing()) 
		// Define if the service is enabled
		AND Not CounterpartiesCheck.CounterpartiesCheckEnabled()
		// Check if a user clicked the Do not show button in the service enable offer
		AND Not CounterpartiesCheck.DoNotShowAgainOfferToConnect()
		// Check if offer to enable service was shown long ago
		AND LastRepresentationOfferToEnableServiceWasLongAgo();
	
	Return RequiredToShowOffer;

EndFunction

// Checks if check is enabled and there are required rights
Function UseChecksAllowed() Export
	
	Return CounterpartiesCheck.HasRightOnCheckingUsage()
		AND CounterpartiesCheck.CounterpartiesCheckEnabled();
	
EndFunction

#EndRegion

#Region Texts

Function CounterpartyCheckResultPresentation(Val Counterparty, TIN, KPP, StorageAddress, Val SourceText = "") Export
	
	Result = SourceText;
	
	UseChecksAllowed = UseChecksAllowed(); 
	If UseChecksAllowed Then
	
		CounterpartyState = CurrentCounterpartyState(Counterparty, TIN, KPP, StorageAddress);
		
		If CounterpartyState = Enums.CounterpartyExistenceStates.ActivitiesDissolved
			OR CounterpartyState = Enums.CounterpartyExistenceStates.NotAvailableInRegistry 
			OR CounterpartyState = Enums.CounterpartyExistenceStates.KKPDoesNotMeetTIN
			OR CounterpartyState = Enums.CounterpartyExistenceStates.Acts Then
			
			// Define label color
			If CounterpartyState = Enums.CounterpartyExistenceStates.ActivitiesDissolved Then
				TextColor = StyleColors.CounterpartyColorTerminatedActivities;
			ElsIf CounterpartyState = Enums.CounterpartyExistenceStates.NotAvailableInRegistry 
				OR CounterpartyState = Enums.CounterpartyExistenceStates.KKPDoesNotMeetTIN Then
				TextColor = StyleColors.CounterpartyColorOutsideRegistry;
			ElsIf CounterpartyState = Enums.CounterpartyExistenceStates.Acts Then
				TextColor = StyleColors.CurrentCounterpartyColor;
			EndIf;
			
			// Form row
			SubstringArray = New Array;
			If ValueIsFilled(SourceText) Then
				SubstringArray.Add(New FormattedString(SourceText,,StyleColors.ErrorCounterpartyHighlightColor));
				SubstringArray.Add("   ");
			EndIf;
			SubstringArray.Add(New FormattedString(String(CounterpartyState),,TextColor,, "DetailsOnCounterpartiesCheck"));
			
			Result = New FormattedString(SubstringArray);
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

Function LastRepresentationOfferToEnableServiceWasLongAgo()
	
	FourHours = 60*60*4;
	DateLastServiceEnableDisplayOffer = CommonSettingsStorage.Load("CounterpartiesCheck_LastDisplaySuggestionsForServiceInclusionDate");
	
	// Do not show an offer
	// to enable service or 4 hours have passed since the last display of warning
	OfferShownLongAgo = DateLastServiceEnableDisplayOffer = Undefined OR 
		DateLastServiceEnableDisplayOffer + FourHours < CurrentSessionDate();
	
	Return OfferShownLongAgo;
	
EndFunction

#EndRegion

