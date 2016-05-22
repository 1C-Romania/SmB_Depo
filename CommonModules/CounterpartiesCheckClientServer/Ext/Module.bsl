////////////////////////////////////////////////////////////////////////////////
// Check one or several counterparties using FTS web service
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface


Function IsActiveCounterpartyState(Status, ExpandStateWithError = True, ExpandWithEmptyState = True) Export
	
	ActiveCounterpartyState = ActiveCounterpartyState(ExpandStateWithError, ExpandWithEmptyState);
	Return ActiveCounterpartyState.Find(Status) <> Undefined;
			
EndFunction

Function ActiveCounterpartyState(ExpandStateWithError = True, ExpandWithEmptyState = True) Export
	
	StateArray = New Array;
	StateArray.Add(PredefinedValue("Enum.CounterpartyExistenceStates.Acts"));
	StateArray.Add(PredefinedValue("Enum.CounterpartyExistenceStates.NotBeChecked"));
	AddAdditionalStates(StateArray, ExpandStateWithError, ExpandWithEmptyState);
	
	Return StateArray;
			
EndFunction

Function IsInactiveCounterpartyState(Status, ExpandStateWithError = False, ExpandWithEmptyState = False) Export
	
	InactiveCounterpartyState = InactiveCounterpartyState(ExpandStateWithError, ExpandWithEmptyState);
	Return InactiveCounterpartyState.Find(Status) <> Undefined;
			
EndFunction
		
Function InactiveCounterpartyState(ExpandStateWithError = False, ExpandWithEmptyState = False) Export
	
	StateArray = New Array;
	StateArray.Add(PredefinedValue("Enum.CounterpartyExistenceStates.KKPDoesNotMeetTIN"));
	StateArray.Add(PredefinedValue("Enum.CounterpartyExistenceStates.NotAvailableInRegistry"));
	StateArray.Add(PredefinedValue("Enum.CounterpartyExistenceStates.ActivitiesDissolved"));
	AddAdditionalStates(StateArray, ExpandStateWithError, ExpandWithEmptyState);
	
	Return StateArray;
			
EndFunction

Function RefForInstruction() Export
	Return New FormattedString(NStr("en = 'Learn more about checking'"),,,,"e1cib/app/DataProcessor.InstructionOnUsageCounterpartiesCheck");
EndFunction

Procedure SetToolTipTextInDocument(RenderParameters) Export
	
	DocumentIsEmpty						= RenderParameters.Property("DocumentIsEmpty") AND RenderParameters.DocumentIsEmpty;
	FieldWithToolTip						= RenderParameters.FieldWithToolTip;
	ParentGroup					= RenderParameters.ParentGroup;
	CheckingState					= RenderParameters.CheckingState;
	CounterpartyFilled	 				= RenderParameters.CounterpartyFilled;
	CounterpartyState 				= RenderParameters.CounterpartyState;
	OutputLabelInPlural = RenderParameters.Property("OutputLabelInPlural");
	
	ParentGroup.BackColor = New Color();
	Substrings = New Array;
	
	If CheckingState = PredefinedValue("Enum.CounterpartiesCheckStates.CheckingNotUsed") Then
		// Display offer for connection
		Substrings.Add(New FormattedString(NStr("en = 'A possibility to use FTS web service to check counterparties registration in EGRN appeared in the application'")));
	ElsIf DocumentIsEmpty Then
		// Report that document for checking is unavailable
		Substrings.Add(New FormattedString(NStr("en = 'A possibility to use FTS web service to check counterparties registration in EGRN appeared in the application'")));
	ElsIf CheckingState = PredefinedValue("Enum.CounterpartiesCheckStates.CheckingInProgress") Then
	    // Check is in progress
		Substrings.Add(New FormattedString(NStr("en = 'Counterparties check is in progress according to FTS data'")));
													  
	ElsIf CheckingState = PredefinedValue("Enum.CounterpartiesCheckStates.AccessDeniedToWebService") Then
		// No access to web service
		
		Substrings.Add(New FormattedString(NStr("en = 'Unable to check counterparties: FTS service is temporarily unavailable'")));
													  
	ElsIf CheckingState = PredefinedValue("Enum.CounterpartiesCheckStates.CheckingExecuted") Then
		// Unfinished counterparty check is in progress
		
		RedColor = New Color(251, 212, 212);
		GreenColor = New Color(215, 240, 199);
		
		If Not CounterpartyFilled Then
			// Counterparty is not filled
			Substrings.Add(NStr("en = 'Check counterparty by FTS base failed: counterparty is not filled'"));
		ElsIf Not ValueIsFilled(CounterpartyState) Then
			// Blank state 
			If OutputLabelInPlural Then
				// Show in plural
				Substrings.Add(NStr("en = 'Counterparties check is in progress according to FTS data'"));
			Else
				// Show in singular
				Substrings.Add(NStr("en = 'Counterparty check is in progress according to FTS data'"));
			EndIf;
		ElsIf CounterpartyState = PredefinedValue("Enum.CounterpartyExistenceStates.NotBeChecked") Then
			// Not Russian counterparty
			Substrings.Add(NStr("en = 'Check counterparty by FTS base failed: only Russian counterparties are subjected to check'"));
		ElsIf CounterpartiesCheckClientServer.IsInactiveCounterpartyState(CounterpartyState) Then
			// Inactive counterparty
			If OutputLabelInPlural Then
				// Display generally
				Substrings.Add(NStr("en = 'Inactive counterparties were found according to FTS data.'"));
			Else
				// Display specific state
				Substrings.Add(String(CounterpartyState));
			EndIf;
			ParentGroup.BackColor = RedColor; 
		ElsIf CounterpartyState = PredefinedValue("Enum.CounterpartyExistenceStates.ContainsErrorsInData") Then
			// Counterparty with errors in TIN/KPP or date
			Substrings.Add(NStr("en = 'Check counterparty by FTS base failed: errors in filling TIN/KPP/date are not found'"));
			ParentGroup.BackColor = RedColor;
		ElsIf CounterpartyState = PredefinedValue("Enum.CounterpartyExistenceStates.Acts") Then
			// Active correct counterparty
			If OutputLabelInPlural Then
				// Display generally 
				Substrings.Add(NStr("en = 'Check of the counterparties according to FTS data is successful'"));
			Else
				// Display specific state
				Substrings.Add(String(CounterpartyState));
			EndIf;
			ParentGroup.BackColor = GreenColor;
		EndIf;
		
	EndIf;
	
	Substrings.Add(Chars.LF);
	Substrings.Add(CounterpartiesCheckClientServer.RefForInstruction());
	
	FieldWithToolTip.ExtendedTooltip.Title = New FormattedString(Substrings);
		
EndProcedure

Procedure ChangePanelKindCounterpartiesChecks(Form, CheckingPanelKind = "") Export
	
	If Form.UseChecksAllowed Then
		
		If ValueIsFilled(CheckingPanelKind) Then 
			
			Form.Items.CheckCounterparty.Visible = True;
			Form.Items.CheckCounterparty.CurrentPage = Form.Items[CheckingPanelKind];
			
			If CheckingPanelKind = "IncorrectCounterpartiesFound" Then
				
				Form.DisplayModeSwitcher = ?(Form.AllRowsDisplayed, "All", "Inactive");
				
			EndIf;
			
		Else
			
			Form.Items.CheckCounterparty.Visible = False;
			
		EndIf;
		
	Else
		Form.Items.CheckCounterparty.Visible = False;
	EndIf;
	
EndProcedure

Function FinalCounterpartyStateInCustomerInvoiceNote(CounterpartiesData, Filter) Export
	
	// Initialize
	CounterpartyFilled 		= False;
	CounterpartyState 	= PredefinedValue("Enum.CounterpartyExistenceStates.EmptyRef");
	
	// Render checking result in customer invoice note
	HasInactiveCounterparties 			= False;
	HasActiveCounterparties 				= False;
	HasCounterpartiesWithErrors 				= False;
	HasCounterpartiesNotSubjectedToCheck 	= False;
	CounterpartyFilled 						= False;
	
	MultipleCounterparties 					= False;
	
	DataByCounterparties = CounterpartiesData.FindRows(Filter);
	If DataByCounterparties.Count() = 1 Then
		
		DataOnCounterparty 	= DataByCounterparties[0];
		CounterpartyFilled 		= ValueIsFilled(DataOnCounterparty.Counterparty); 
		CounterpartyState 	= DataOnCounterparty.Status;
		MultipleCounterparties 	= False;
		
	Else
	
		For Each DataOnCounterparty IN DataByCounterparties Do
			
			// Counterparty fullness
			If ValueIsFilled(DataOnCounterparty.Counterparty) Then
				CounterpartyFilled = True;
			EndIf;
			
			// State of existence
			If CounterpartiesCheckClientServer.IsInactiveCounterpartyState(DataOnCounterparty.Status) Then
				HasInactiveCounterparties = True;
			EndIf;
			
			If CounterpartiesCheckClientServer.IsActiveCounterpartyState(DataOnCounterparty.Status) 
				AND DataOnCounterparty.Status <> PredefinedValue("Enum.CounterpartyExistenceStates.ContainsErrorsInData")
				AND DataOnCounterparty.Status <> PredefinedValue("Enum.CounterpartyExistenceStates.EmptyRef")
				AND DataOnCounterparty.Status <> PredefinedValue("Enum.CounterpartyExistenceStates.NotBeChecked") Then
				HasActiveCounterparties = True;
			EndIf;
			
			If DataOnCounterparty.Status = PredefinedValue("Enum.CounterpartyExistenceStates.ContainsErrorsInData") Then
				HasCounterpartiesWithErrors = True;
			EndIf;
			
			If DataOnCounterparty.Status = PredefinedValue("Enum.CounterpartyExistenceStates.NotBeChecked") Then
				HasCounterpartiesNotSubjectedToCheck = True;
			EndIf;
			
		EndDo;
		
		If CounterpartyFilled Then
			MultipleCounterparties = True;
		EndIf;
		
		If Not HasInactiveCounterparties AND Not HasActiveCounterparties AND Not HasCounterpartiesWithErrors Then
			// Counterparty is not checked
		    CounterpartyState = PredefinedValue("Enum.CounterpartyExistenceStates.EmptyRef");
		ElsIf HasInactiveCounterparties Then
			CounterpartyState = PredefinedValue("Enum.CounterpartyExistenceStates.NotAvailableInRegistry");
		ElsIf HasCounterpartiesWithErrors Then
			CounterpartyState = PredefinedValue("Enum.CounterpartyExistenceStates.ContainsErrorsInData");
		ElsIf HasCounterpartiesNotSubjectedToCheck Then
			CounterpartyState = PredefinedValue("Enum.CounterpartyExistenceStates.NotBeChecked");
		Else
			CounterpartyState = PredefinedValue("Enum.CounterpartyExistenceStates.Acts");
		EndIf;
		
	EndIf;
	
	Result = New Structure;
	Result.Insert("CounterpartyFilled", 		CounterpartyFilled);
	Result.Insert("CounterpartyState", 		CounterpartyState);
	Result.Insert("MultipleCounterparties", 	MultipleCounterparties);
	
	Return Result;
	
EndFunction

#EndRegion

#Region HelperProceduresAndFunctions

Procedure AddAdditionalStates(StateArray, ExpandStateWithError, ExpandWithEmptyState)
	
	If ExpandStateWithError Then
		StateArray.Add(PredefinedValue("Enum.CounterpartyExistenceStates.ContainsErrorsInData"));
	EndIf;
	If ExpandWithEmptyState Then
		StateArray.Add(PredefinedValue("Enum.CounterpartyExistenceStates.EmptyRef"));
	EndIf;
	
EndProcedure

#EndRegion