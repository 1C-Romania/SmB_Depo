&AtClient
Var ResponseBeforeClose;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Form initialization
	For MonthNumber = 1 To 12 Do
		Items.AnnualCopiesFormingMonth.ChoiceList.Add(MonthNumber, 
			Format(Date(2, MonthNumber, 1), "DF=MMMM"));
	EndDo;
	
	SetWidthOfSignatures();
	
	ApplyRestrictionsSettings();
	
	FillFormBySettings(Parameters.DataSettings);
	
EndProcedure

&AtClient
Procedure DailyCopiesAmountOnChange(Item)
	
	SignatureCountOfDaily = SignatureNumberOfCopies(DailyCopiesAmount);
	
EndProcedure

&AtClient
Procedure MonthlyCopiesAmountOnChange(Item)
	
	SignatureOfMonthly = SignatureNumberOfCopies(MonthlyCopiesAmount);
	
EndProcedure

&AtClient
Procedure AnnualCopiesAmountOnChange(Item)
	
	SignatureCountAnnual = SignatureNumberOfCopies(AnnualCopiesAmount);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not Modified Then
		Return;
	EndIf;
	
	If ResponseBeforeClose <> True Then
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeCloseEnd", ThisObject);
		ShowQueryBox(NOTifyDescription, NStr("en = 'Data was changed. Save changes?'"), 
			QuestionDialogMode.YesNoCancel, , DialogReturnCode.Yes);
	EndIf;
		
EndProcedure
		
&AtClient
Procedure BeforeCloseEnd(Response, AdditionalParameters) Export	
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Response = DialogReturnCode.Yes Then
		WriteNewSettings();
	EndIf;
	ResponseBeforeClose = True;
    Close();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Reread(Command)
	
	RereadAtServer();
	
EndProcedure

&AtClient
Procedure Write(Command)
	
	WriteNewSettings();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteNewSettings();
	Close();
	
EndProcedure

&AtClient
Procedure SetStandardSettings(Command)
	
	SetStandardSettingsAtServer();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure RereadAtServer()
	
	FillFormBySettings(
		DataAreasBackupDataFormsInterface.GetAreaSettings(Parameters.DataArea));
		
	Modified = False;
	
EndProcedure

&AtServer
Procedure FillFormBySettings(Val DataSettings, Val UpdateInitialSettings = True)
	
	FillPropertyValues(ThisObject, DataSettings);
	
	If UpdateInitialSettings Then
		InitialSettings = DataSettings;
	EndIf;
	
	SetSignaturesAllQuantities();
	
EndProcedure

&AtServer
Procedure SetWidthOfSignatures()
	
	MaximumWidth = 0;
	
	NumbersForVerification = New Array;
	NumbersForVerification.Add(1);
	NumbersForVerification.Add(2);
	NumbersForVerification.Add(5);
	
	For Each Number IN NumbersForVerification Do
		LabelWidth = StrLen(SignatureNumberOfCopies(Number));
		If LabelWidth > MaximumWidth Then
			MaximumWidth = LabelWidth;
		EndIf;
	EndDo;
	
	SignatureItems = New Array;
	SignatureItems.Add(Items.SignatureCountOfDaily);
	SignatureItems.Add(Items.SignatureOfMonthly);
	SignatureItems.Add(Items.SignatureCountAnnual);
	
	For Each SignatureItem IN SignatureItems Do
		SignatureItem.Width = MaximumWidth;
	EndDo;
	
EndProcedure

&AtServer
Procedure ApplyRestrictionsSettings()
	
	RestrictionsSettings = Parameters.RestrictionsSettings;
	
	ToolTipTemplate = NStr("en = 'Maximum %1'");
	
	ItemsRestrictions = New Structure;
	ItemsRestrictions.Insert("DailyCopiesAmount", "MaxDailyCopies");
	ItemsRestrictions.Insert("MonthlyCopiesAmount", "MaxMonthlyCopies");
	ItemsRestrictions.Insert("AnnualCopiesAmount", "MaxAnnualCopies");
	
	For Each KeyAndValue IN ItemsRestrictions Do
		Item = Items[KeyAndValue.Key];
		Item.MaxValue = RestrictionsSettings[KeyAndValue.Value];
		Item.ToolTip = 
			StringFunctionsClientServer.PlaceParametersIntoString(
				ToolTipTemplate, 
				RestrictionsSettings[KeyAndValue.Value]);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetSignaturesAllQuantities()
	
	SignatureCountOfDaily = SignatureNumberOfCopies(DailyCopiesAmount);
	SignatureOfMonthly = SignatureNumberOfCopies(MonthlyCopiesAmount);
	SignatureCountAnnual = SignatureNumberOfCopies(AnnualCopiesAmount);
	
EndProcedure

&AtClientAtServerNoContext
Function SignatureNumberOfCopies(Val Quantity)

	PresentationArray = New Array;
	PresentationArray.Add(NStr("en = 'last copy'"));
	PresentationArray.Add(NStr("en = 'Last copies'"));
	PresentationArray.Add(NStr("en = 'of last copies'"));
	
	If Quantity >= 100 Then
		Quantity = Quantity - Int(Quantity / 100)*100;
	EndIf;
	
	If Quantity > 20 Then
		Quantity = Quantity - Int(Quantity/10)*10;
	EndIf;
	
	If Quantity = 1 Then
		Result = PresentationArray[0];
	ElsIf Quantity > 1 AND Quantity < 5 Then
		Result = PresentationArray[1];
	Else
		Result = PresentationArray[2];
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure WriteNewSettings()
	
	NewSettings = New Structure;
	For Each KeyAndValue IN InitialSettings Do
		NewSettings.Insert(KeyAndValue.Key, ThisObject[KeyAndValue.Key]);
	EndDo;
	
	NewSettings = New FixedStructure(NewSettings);
	
	DataAreasBackupDataFormsInterface.SetAreasSettings(
		Parameters.DataArea,
		NewSettings,
		InitialSettings);
		
	Modified = False;
	InitialSettings = NewSettings;
	
EndProcedure

&AtServer
Procedure SetStandardSettingsAtServer()
	
	FillFormBySettings(
		DataAreasBackupDataFormsInterface.GetStandardSettings(),
		False);
	
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
