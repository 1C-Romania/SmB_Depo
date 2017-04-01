
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Title allocation.
	If Not IsBlankString(Parameters.Title) Then
		Title = Parameters.Title;
		HeaderWidth = 1.3 * StrLen(Title);
		If HeaderWidth > 40 AND HeaderWidth < 80 Then
			Width = HeaderWidth;
		EndIf;
	EndIf;
	
	If Parameters.LockWholeInterface Then
		WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface;
	EndIf;
	
	// Picture 
	If Parameters.Picture.Type <> PictureType.Empty Then
		Items.Warning.Picture = Parameters.Picture;
	EndIf;
	
	// Text allocation.
	If StrLineCount(Parameters.MessageText) < 15 Then
		// You can show all rows as a label.
		Items.MessageText.Title = Parameters.MessageText;
		Items.MultipageMessageText.Visible = False;
	Else
		// Multiline mode.
		Items.MessageText.Visible = False;
		MessageText = Parameters.MessageText;
	EndIf;
	
	// Flag placement.
	If ValueIsFilled(Parameters.FlagText) Then
		Items.DontAskAgain.Title = Parameters.FlagText;
	ElsIf Not AccessRight("SaveUserData", Metadata) OR Not Parameters.OfferDontAskAgain Then
		Items.DontAskAgain.Visible = False;
	EndIf;
	
	// Buttons placement.
	AddCommandsAndButtonsOnForm(Parameters.Buttons);
	
	// Setting up the default button.
	SetDefaultButton(Parameters.DefaultButton);
	
	// Setting up the countdown button.
	SetStandbyButton(Parameters.TimeoutButton);
	
	// Setting up the countdown timer.
	ExpectationCounter = Parameters.Timeout;
	
	// Reset size and position of window of this form.
	UnsetWindowSizeAndLocation();
	
	// In order for command panel does not disappear during the countdown.
	Items.MessageText.Title = Items.MessageText.Title + Chars.LF + Chars.LF;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// Start the countdown.
	If ExpectationCounter >= 1 Then
		ExpectationCounter = ExpectationCounter + 1;
		ReturnMessageTextSize();
		ContinueCountdown();
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure Attachable_CommandHandler(Command)
	ValueSelected = ButtonAndReturnValueMatching.Get(Command.Name);
	
	ChoiceResult = New Structure;
	ChoiceResult.Insert("DontAskAgain", DontAskAgain);
	ChoiceResult.Insert("Value", DialogReturnCodeByValue(ValueSelected));
	
	Close(ChoiceResult);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure ContinueCountdown()
	ExpectationCounter = ExpectationCounter - 1;
	If ExpectationCounter <= 0 Then
		Close(New Structure("DontAskAgain, Value", False, DialogReturnCode.Timeout));
	Else
		If WaitingButtonName <> "" Then
			NewHeader = (
				IdleButtonTitle
				+ " ("
				+ StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='left %1 sec.';ru='осталось %1 сек.'"),
				String(ExpectationCounter))
				+ ")");
				
			Items[WaitingButtonName].Title = NewHeader;
		EndIf;
		AttachIdleHandler("ContinueCountdown", 1, True);
	EndIf;
EndProcedure

&AtServer
Procedure ReturnMessageTextSize()
	Items.MessageText.Title = TrimAll(Items.MessageText.Title);
EndProcedure

&AtClient
Function DialogReturnCodeByValue(Value)
	If TypeOf(Value) <> Type("String") Then
		Return Value;
	EndIf;
	
	If Value = "DialogReturnCode.Yes" Then
		Result = DialogReturnCode.Yes;
	ElsIf Value = "DialogReturnCode.No" Then
		Result = DialogReturnCode.No;
	ElsIf Value = "DialogReturnCode.OK" Then
		Result = DialogReturnCode.OK;
	ElsIf Value = "DialogReturnCode.Cancel" Then
		Result = DialogReturnCode.Cancel;
	ElsIf Value = "ReturnDialogCode.Retry" Then
		Result = DialogReturnCode.Retry;
	ElsIf Value = "DialogReturnCode.Abort" Then
		Result = DialogReturnCode.Abort;
	ElsIf Value = "DialogReturnCode.Ignore" Then
		Result = DialogReturnCode.Ignore;
	Else
		Result = Value;
	EndIf;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure AddCommandsAndButtonsOnForm(Buttons)
	// Adds commands and corresponding buttons on the form.
	//
	// Parameters:
	//  Buttons - String / ValueList - buttons
	// 	   set if the string - String identifier in the format "QuestionDialogMode.<one of the values QuestionDialogMode>",
	// 	   for example "QuestionDialogMode.YesNo" if ValueList - for each record,
	// 	   Value - return value form when clicking the button.
	//		  Presentation - button title.
	
	If TypeOf(Buttons) = Type("String") Then
		ButtonsValueList = StandardSet(Buttons);
	Else
		ButtonsValueList = Buttons;
	EndIf;
	
	ButtonToValueMapping = New Map;
	
	IndexOf = 0;
	
	For Each ButtonInfoItem IN ButtonsValueList Do
		IndexOf = IndexOf + 1;
		CommandName = "Command" + String(IndexOf);
		Command = Commands.Add(CommandName);
		Command.Action  = "Attachable_CommandHandler";
		Command.Title = ButtonInfoItem.Presentation;
		Command.ModifiesStoredData = False;
		
		Button= Items.Add(CommandName, Type("FormButton"), Items.CommandBar);
		Button.OnlyInAllActions = False;
		Button.CommandName = CommandName;
		
		ButtonToValueMapping.Insert(CommandName, ButtonInfoItem.Value);
	EndDo;
	
	ButtonAndReturnValueMatching = New FixedMap(ButtonToValueMapping);
EndProcedure

&AtServer
Procedure SetDefaultButton(DefaultButton)
	If ButtonAndReturnValueMatching.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Item IN ButtonAndReturnValueMatching Do
		If Item.Value = DefaultButton Then
			Items[Item.Key].DefaultButton = True;
			Return;
		EndIf;
	EndDo;
	
	Items.CommandBar.ChildItems[0].DefaultButton = True;
EndProcedure

&AtServer
Procedure SetStandbyButton(IdleButtonValue)
	If ButtonAndReturnValueMatching.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Item IN ButtonAndReturnValueMatching Do
		If Item.Value = IdleButtonValue Then
			WaitingButtonName = Item.Key;
			IdleButtonTitle = Commands[WaitingButtonName].Title;
			Return;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure UnsetWindowSizeAndLocation()
	UserName = InfobaseUsers.CurrentUser().Name;
	If AccessRight("SaveUserData", Metadata) Then
		SystemSettingsStorage.Delete("CommonForm.Question", "", UserName);
	EndIf;
	WindowOptionsKey = String(New UUID);
EndProcedure

&AtServerNoContext
Function StandardSet(Buttons)
	Result = New ValueList;
	
	If Buttons = "DialogModeQuestion.YesNo" Then
		Result.Add("DialogReturnCode.Yes",  NStr("en='Yes';ru='Да'"));
		Result.Add("DialogReturnCode.No", NStr("en='No';ru='Нет'"));
	ElsIf Buttons = "QuestionDialogMode.YesNoCancel" Then
		Result.Add("DialogReturnCode.Yes",     NStr("en='Yes';ru='Да'"));
		Result.Add("DialogReturnCode.No",    NStr("en='No';ru='Нет'"));
		Result.Add("DialogReturnCode.Cancel", NStr("en='Cancel';ru='Отменить'"));
	ElsIf Buttons = "DialogModeQuestion.OK" Then
		Result.Add("DialogReturnCode.OK", NStr("en='OK';ru='Ок'"));
	ElsIf Buttons = "QuestionDialogMode.OKCancel" Then
		Result.Add("DialogReturnCode.OK",     NStr("en='OK';ru='Ок'"));
		Result.Add("DialogReturnCode.Cancel", NStr("en='Cancel';ru='Отменить'"));
	ElsIf Buttons = "QuestionDialogMode.RetryCancel" Then
		Result.Add("ReturnDialogCode.Retry", NStr("en='Retry';ru='Повторить'"));
		Result.Add("DialogReturnCode.Cancel",    NStr("en='Cancel';ru='Отменить'"));
	ElsIf Buttons = "QuestionDialogMode.AbortRetryIgnore" Then
		Result.Add("DialogReturnCode.Abort",   NStr("en='Break';ru='Прервать'"));
		Result.Add("ReturnDialogCode.Retry",  NStr("en='Retry';ru='Повторить'"));
		Result.Add("DialogReturnCode.Ignore", NStr("en='Skip';ru='Пропустить'"));
	EndIf;
	
	Return Result;
EndFunction

#EndRegion














