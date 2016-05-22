
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	UserPresentation           = Parameters.UserPresentation;
	SectionPresentation        = Parameters.SectionPresentation;
	ObjectPresentation         = Parameters.ObjectPresentation;
	ProhibitionDateDescription = Parameters.ProhibitionDateDescription;
	PermissionDaysCount        = Parameters.PermissionDaysCount;
	ProhibitionDate            = Parameters.ProhibitionDate;
	
	AllowDataChangingToProhibitionDate = PermissionDaysCount > 0;
	
	If Not ValueIsFilled(SectionPresentation) Then
		Items.SectionPresentation.Visible = False;
	EndIf;
	
	If Not ValueIsFilled(ObjectPresentation) Then
		Items.ObjectPresentation.Visible = False;
	EndIf;
	
	If Not Parameters.AllowByDefault Then
		Items.ProhibitionDateDescription.ChoiceList.Delete(0);
	EndIf;
	
	// Caching the current date on the server.
	CurrentDateAtServer = CurrentSessionDate();
	
	CommonProhibitionDateWithDescriptionOnChangeAdditionally(ThisObject);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	NotifyChoice(ReturnValue);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

////////////////////////////////////////////////////////////////////////////////
// Same event handlers of forms ChangeProhibitionDates and ProhibitionDateEditing.

&AtClient
Procedure ProhibitionDateDescriptionOnChange(Item)
	
	CommonProhibitionDateWithDescriptionOnChangeAdditionally(ThisObject);
	
EndProcedure

&AtClient
Procedure ProhibitionDateOnChange(Item)
	
	CommonProhibitionDateWithDescriptionOnChangeAdditionally(ThisObject);
	
EndProcedure

&AtClient
Procedure AllowDataChangingToProhibitionDateOnChange(Item)
	
	CommonProhibitionDateWithDescriptionOnChangeAdditionally(ThisObject);
	
EndProcedure

&AtClient
Procedure PermissionDaysCountOnChange(Item)
	
	CommonProhibitionDateWithDescriptionOnChangeAdditionally(ThisObject);
	
EndProcedure

&AtClient
Procedure PermissionDaysCountAutoCompleteText(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	PermissionDaysCount = Text;
	
	CommonProhibitionDateWithDescriptionOnChangeAdditionally(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ReturnValue = New Structure;
	ReturnValue.Insert("ProhibitionDateDescription",      ProhibitionDateDescription);
	ReturnValue.Insert("PermissionDaysCount", PermissionDaysCount);
	ReturnValue.Insert("ProhibitionDate",              ProhibitionDate);
	
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Procedure CommonProhibitionDateWithDescriptionOnChangeAdditionally(Val Context)
	
	If Context.ProhibitionDateDescription = "" Then
		Context.Items.AutomaticalDateProperties.CurrentPage =
			Context.Items.AutomaticalDateNotUsed;
		
		Context.Items.Custom.CurrentPage =
			Context.Items.ArbitraryDateIsNotUsed;
		
		Context.AllowDataChangingToProhibitionDate = False;
		Context.PermissionDaysCount = 0;
		Context.ProhibitionDate = '00000000';
	Else
		CommonProhibitionDateWithDescriptionOnChange(Context);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Same procedure and function of forms ChangeProhibitionDates and ProhibitionDateEditing.

&AtClientAtServerNoContext
Procedure CommonProhibitionDateWithDescriptionOnChange(Val Context, CalculateProhibitionDate = True)
	
	TwentyFourHours = 60*60*24;
	
	If Context.ProhibitionDateDescription = "Custom" Then
		Context.Items.AutomaticalDateProperties.CurrentPage =
			Context.Items.AutomaticalDateNotUsed;
		
		Context.Items.Custom.CurrentPage =
			Context.Items.ArbitraryDateIsUsed;
		
		Context.AllowDataChangingToProhibitionDate = False;
		Context.PermissionDaysCount = 0;
	Else
		Context.Items.AutomaticalDateProperties.CurrentPage =
			Context.Items.AutomaticalDateUsed;
		
		Context.Items.Custom.CurrentPage =
			Context.Items.ArbitraryDateIsNotUsed;
		
		If Context.ProhibitionDateDescription = "PreviousDay" Then
			Context.Items.AllowDataChangingToProhibitionDate.Enabled = False;
			Context.AllowDataChangingToProhibitionDate = False;
		Else
			Context.Items.AllowDataChangingToProhibitionDate.Enabled = True;
		EndIf;
		CalculatedProhibitionDates = ProhibitionDateCalculation(
			Context.ProhibitionDateDescription, Context.CurrentDateAtServer);
		
		If CalculateProhibitionDate Then
			Context.ProhibitionDate = CalculatedProhibitionDates.Current;
		EndIf;
		LabelText = "";
		If Context.AllowDataChangingToProhibitionDate Then
			ToCorrectPermissionDaysCount(
				Context.ProhibitionDateDescription, Context.PermissionDaysCount);
			
			Context.Items.PropertyPermissionDaysCountChanges.CurrentPage =
				Context.Items.DataChangingBeforeProhibitionDateIsAllowed;
			
			PermissionTerm =
				CalculatedProhibitionDates.Current + Context.PermissionDaysCount * TwentyFourHours;
			
			If Context.CurrentDateAtServer > PermissionTerm Then
				LabelText = Chars.LF
				             + NStr("en = 'Term possibility of changing data from %3 to %4 expired %2'");
			Else
				If CalculateProhibitionDate Then
					Context.ProhibitionDate = CalculatedProhibitionDates.Previous;
				EndIf;
				LabelText = Chars.LF
				             + NStr("en = 'To %2 change of data is possible from %3 to %4'")
				             + Chars.LF
				             + NStr("en = 'After %2 change of data will be forbidden to %4'")
				             + Chars.LF;
			EndIf;
		Else
			Context.Items.PropertyPermissionDaysCountChanges.CurrentPage =
				Context.Items.DataChangingBeforeProhibitionDateIsNotAllowed;
			
			Context.PermissionDaysCount = 0;
		EndIf;
		Context.Items.AutomaticalDateExplanation.Title =
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Change of data is forbidden to %1'") + LabelText,
				Format(Context.ProhibitionDate, "DLF=D"),
				Format(PermissionTerm, "DLF=D"),
				Format(CalculatedProhibitionDates.Previous + TwentyFourHours, "DLF=D"),
				Format(CalculatedProhibitionDates.Current, "DLF=D"));
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function ProhibitionDateCalculation(Val RegistrationDateVariant, Val CurrentDateAtServer)
	
	TwentyFourHours = 60*60*24;
	
	CurrentProhibitionDate    = '00000000';
	PreviousProhibitionDate = '00000000';
	
	If RegistrationDateVariant = "LastYearEnd" Then
		CurrentProhibitionDate    = BegOfYear(CurrentDateAtServer) - TwentyFourHours;
		PreviousProhibitionDate = BegOfYear(CurrentProhibitionDate)   - TwentyFourHours;
		
	ElsIf RegistrationDateVariant = "LastQuarterEnd" Then
		CurrentProhibitionDate    = BegOfQuarter(CurrentDateAtServer) - TwentyFourHours;
		PreviousProhibitionDate = BegOfQuarter(CurrentProhibitionDate)   - TwentyFourHours;
		
	ElsIf RegistrationDateVariant = "LastMonthEnd" Then
		CurrentProhibitionDate    = BegOfMonth(CurrentDateAtServer) - TwentyFourHours;
		PreviousProhibitionDate = BegOfMonth(CurrentProhibitionDate)   - TwentyFourHours;
		
	ElsIf RegistrationDateVariant = "LastWeekEnd" Then
		CurrentProhibitionDate    = BegOfWeek(CurrentDateAtServer) - TwentyFourHours;
		PreviousProhibitionDate = BegOfWeek(CurrentProhibitionDate)   - TwentyFourHours;
		
	ElsIf RegistrationDateVariant = "PreviousDay" Then
		CurrentProhibitionDate    = BegOfDay(CurrentDateAtServer) - TwentyFourHours;
		PreviousProhibitionDate = BegOfDay(CurrentProhibitionDate)   - TwentyFourHours;
	EndIf;
	
	Return New Structure("Current, Previous", CurrentProhibitionDate, PreviousProhibitionDate);
	
EndFunction

&AtClientAtServerNoContext
Procedure ToCorrectPermissionDaysCount(Val ProhibitionDateDescription, PermissionDaysCount)
	
	If PermissionDaysCount = 0 Then
		PermissionDaysCount = 1;
		
	ElsIf ProhibitionDateDescription = "LastYearEnd" Then
		If PermissionDaysCount > 90 Then
			PermissionDaysCount = 90;
		EndIf;
		
	ElsIf ProhibitionDateDescription = "LastQuarterEnd" Then
		If PermissionDaysCount > 60 Then
			PermissionDaysCount = 60;
		EndIf;
		
	ElsIf ProhibitionDateDescription = "LastMonthEnd" Then
		If PermissionDaysCount > 25 Then
			PermissionDaysCount = 25;
		EndIf;
		
	ElsIf ProhibitionDateDescription = "LastWeekEnd" Then
		If PermissionDaysCount > 5 Then
			PermissionDaysCount = 5;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
