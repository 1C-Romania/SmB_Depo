&AtClient
Var UsersContinueAdding;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		InterfaceVersion82 = True;
		Items.UsersAdd.OnlyInAllActions = False;
		Items.ProhibitionDatesAdd.OnlyInAllActions = False;
	EndIf;
	
	// Fill in section properties.
	SectionsProperties = ChangeProhibitionDatesServiceReUse.SectionsProperties();
	FillPropertyValues(ThisObject, SectionsProperties, , "SectionObjectsTypes");
	ValueToFormAttribute(SectionsProperties.SectionObjectsTypes, "SectionObjectsTypes");
	FirstSection = ?(
		SectionObjectsTypes.Count() = 1, SectionObjectsTypes[0].Section, SectionEmptyRef);
	
	// Form fields setting
	If Parameters.DataImportingProhibitionDates Then
		
		If Not SectionsProperties.UseProhibitionDatesOfDataImport Then
			Raise(NStr("en='Closing dates of data import are not used.';ru='Даты запрета загрузки данных не используются.'"));
		EndIf;
		
		Title = NStr("en='Closing dates of data import';ru='Даты запрета загрузки данных'");
		Items.ProhibitionDateSetting.ChoiceList.FindByValue("NoProhibition").Presentation =
			NStr("en='Data import allowed';ru='Нет запрета загрузки данных'");
		Items.ProhibitionDateSetting.ChoiceList.FindByValue("ForAllUsers").Presentation =
			NStr("en='For all infobases';ru='Для всех информационных баз'");
		Items.ProhibitionDateSetting.ChoiceList.FindByValue("ByUsers").Presentation =
			NStr("en='By infobases';ru='По информационным базам'");
		
		Items.Reports.ToolTip
			= NStr("en='Reports by the data
		|import prohibition dates set ""By the infobases"".';ru='Отчеты по
		|датам запрета загрузки данных, установленным ""По информационным базам"".'");
		
		Commands.ProhibitionDatesByUsers.Title
			= NStr("en='Closing dates by infobases';ru='Даты запрета по информационным базам'");
		
		Commands.ProhibitionDatesByUsers.ToolTip
			= NStr("en='Data import prohibition
		|dates by the infobases and applications.';ru='Даты запрета
		|загрузки данных по информационным базам и программам.'");
		
		Commands.ProhibitionDatesBySectionsObjectsForUsers.Title =
			NStr("en='Closing dates by sections and objects for infobases';ru='Даты запрета по разделам и объектам для информационных баз'");
		
		Commands.ProhibitionDatesBySectionsObjectsForUsers.ToolTip =
			NStr("en='Data import prohibition
		|dates by sections and objects for infobases and applications.';ru='Даты запрета
		|загрузки данных по разделам и объектам для информационных баз и программ.'");
		
		Items.UsersFullPresentation.Title =
			NStr("en='Application: infobase';ru='Программа: информационная база'");
		
		ValueForAllUsers =
			Enums.ProhibitionDatesPurposeKinds.ForAllDatabases;
		
		TypesUser =
			Metadata.InformationRegisters.ChangeProhibitionDates.Dimensions.User.Type.Types();
		
		For Each UserType IN TypesUser Do
			MetadataObject = Metadata.FindByType(UserType);
			If Not Metadata.ExchangePlans.Contains(MetadataObject) Then
				Continue;
			EndIf;
			ExchangePlanNodeEmptyRef = CommonUse.ObjectManagerByFullName(
				MetadataObject.FullName()).EmptyRef();
			
			ListOfUserTypes.Add(
				ExchangePlanNodeEmptyRef, MetadataObject.Presentation());
		EndDo;
		Items.Users.RowsPicture = PictureLib.ExchangePlanNodeIcons;
	Else
		ValueForAllUsers = Enums.ProhibitionDatesPurposeKinds.ForAllUsers;
		
		ListOfUserTypes.Add(
			Type("CatalogRef.Users"),        NStr("en='User';ru='Пользователь'"));
		
		ListOfUserTypes.Add(
			Type("CatalogRef.ExternalUsers"), NStr("en='External user';ru='Внешний пользователь'"));
	EndIf;
	
	List = Items.ProhibitionDateSpecifiedMode.ChoiceList;
	
	If WithoutSectionsAndObjects Then
		Items.ProhibitionDateSpecifiedMode.Visible =
			ValueIsFilled(ProhibitionDateCurrentSpecifiedMode(
				"*", SingleSection, FirstSection, ValueForAllUsers));
		
		List.Delete(List.FindByValue("BySectionsAndObjects"));
		List.Delete(List.FindByValue("BySections"));
		List.Delete(List.FindByValue("ByObjects"));
		
	ElsIf Not ShowSections Then
		Items.ProhibitionDatesBySectionsObjectsForUsers.Title =
			ReportByObjectCommandHeaderText();
		
		List.Delete(List.FindByValue("BySectionsAndObjects"));
		List.Delete(List.FindByValue("BySections"));
		
	ElsIf AllSectionsWithoutObjects Then
		Items.ProhibitionDatesBySectionsObjectsForUsers.Title =
			ReportBySectionsCommandHeaderText();
		
		List.Delete(List.FindByValue("BySectionsAndObjects"));
		List.Delete(List.FindByValue("ByObjects"));
	Else
		List.Delete(List.FindByValue("ByObjects"));
	EndIf;
	
	UseExternalUsers = UseExternalUsers
		AND ExternalUsers.UseExternalUsers();
	
	CatalogExternalUsersEnabled =
		AccessRight("view", Metadata.Catalogs.ExternalUsers);
	
	UpdateAtServer();
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(
		ThisObject, "CurrentUserPresentation");
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName)
	   = Upper("InformationRegister.ChangeProhibitionDates.Form.ProhibitionDateEditing") Then
		
		If ValueSelected <> Undefined Then
			SelectedRows = Items.ProhibitionDates.SelectedRows;
			
			For Each SelectedRow IN SelectedRows Do
				String = ProhibitionDates.FindByID(SelectedRow);
				String.ProhibitionDateDescription              = ValueSelected.ProhibitionDateDescription;
				String.PermissionDaysCount         = ValueSelected.PermissionDaysCount;
				String.ProhibitionDate                      = ValueSelected.ProhibitionDate;
				WriteDescriptionAndProhibitionDate(String);
				String.ProhibitionDateDescriptionPresentation = PresentationOfProhibitionDateDescription(String);
			EndDo;
			UpdateExistsProhibitionDatesOfCurrentUser();
		EndIf;
		
		// Cancel the selected strings lock.
		UnlockAllRecords(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	QuestionText = QuestionTextAboutUnsavedData();
	
	TextNotifications = TextNotificationsOfUnusedSettingModes();
	
	If Not ValueIsFilled(QuestionText) Then
		QuestionText = TextNotifications;
		TextNotifications = "";
	EndIf;
	
	If ValueIsFilled(TextNotifications) Then
		QuestionText = QuestionText + Chars.LF + Chars.LF + TextNotifications;
	EndIf;
	
	If ValueIsFilled(QuestionText) Then
		QuestionText = QuestionText + Chars.LF + Chars.LF + QuestionTextCloseForm();
		CommonUseClient.ShowArbitraryFormClosingConfirmation(
			ThisObject, Cancel, QuestionText, "CloseFormWithoutConfirmation");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	UnlockAllRecords(ThisObject);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ProhibitionDateSettingClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ProhibitionDateSettingChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If ProhibitionDateSetting = ValueSelected Then
		Return;
	EndIf;
	
	ProhibitionDateCurrentSetting = ProhibitionDateCurrentSetting(Parameters.DataImportingProhibitionDates);
	
	If ProhibitionDateCurrentSetting = "ByUsers"
	   AND ValueSelected = "ForAllUsers" Then
		
		QuestionText = QuestionTextDeleteAllProhibitionDatesExceptDatesForAllUsers();
		
	ElsIf ProhibitionDateCurrentSetting = "ByUsers"
	        AND ValueSelected = "NoProhibition" Then
		
		QuestionText = QuestionTextDeleteAllProhibitionDates();
		
	ElsIf ProhibitionDateCurrentSetting = "ForAllUsers"
	        AND ValueSelected = "NoProhibition" Then
		
		QuestionText = QuestionTextDeleteAllProhibitionDates();
	EndIf;
	
	If ValueIsFilled(QuestionText) Then
		ShowQueryBox(
			New NotifyDescription(
				"ProhibitionDateSettingSelectionProcessingContinue", ThisObject, ValueSelected),
			QuestionText,
			QuestionDialogMode.YesNo);
	Else
		ProhibitionDateSetting = ValueSelected;
		ChangeProhibitionDateSetting(ValueSelected, False);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProhibitionDateSpecifiedModeClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ProhibitionDateSpecifiedModeChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If ProhibitionDateSpecifiedMode = ValueSelected Then
		Return;
	EndIf;
	
	Data = Undefined;
	CurrentMode = ProhibitionDateCurrentSpecifiedMode(CurrentUser, SingleSection, FirstSection, ValueForAllUsers, Data);
	
	QuestionText = "";
	If CurrentMode = "BySectionsAndObjects" AND ValueSelected = "CommonDate" Then
		QuestionText = QuestionTextDeleteProhibitionDatesForSectionsAndObjects();
		
	ElsIf CurrentMode = "BySectionsAndObjects" AND ValueSelected = "BySections"
	      OR CurrentMode = "ByObjects"          AND ValueSelected = "CommonDate" Then
		QuestionText = QuestionTextDeleteProhibitionDatesForObjects();
		
	ElsIf CurrentMode = "BySectionsAndObjects" AND ValueSelected = "ByObjects"
	      OR CurrentMode = "BySections"          AND ValueSelected = "ByObjects"
	      OR CurrentMode = "BySections"          AND ValueSelected = "CommonDate" Then
		QuestionText = QuestionTextDeleteProhibitionDatesForSections();
		
	EndIf;
	
	If ValueIsFilled(QuestionText) Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Data", Data);
		AdditionalParameters.Insert("ValueSelected", ValueSelected);
		
		ShowQueryBox(
			New NotifyDescription(
				"ProhibitionDateSpecificationMethodSelectionProcessingContinue",
				ThisObject,
				AdditionalParameters),
			QuestionText,
			QuestionDialogMode.YesNo);
	Else
		ProhibitionDateSpecifiedMode = ValueSelected;
		ReadUserData(ThisObject, ValueSelected, Data);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Same event handlers of forms ChangeProhibitionDates and ProhibitionDateEditing.

&AtClient
Procedure ProhibitionDateDescriptionOnChange(Item)
	
	CommonProhibitionDateWithDescriptionOnChange(ThisObject);
	WriteCommonProhibitionDateWithDescription();
	
EndProcedure

&AtClient
Procedure ProhibitionDateOnChange(Item)
	
	CommonProhibitionDateWithDescriptionOnChange(ThisObject);
	WriteCommonProhibitionDateWithDescription();
	
	UpdateExistsProhibitionDatesOfCurrentUser();
	
EndProcedure

&AtClient
Procedure AllowDataChangingToProhibitionDateOnChange(Item)
	
	CommonProhibitionDateWithDescriptionOnChange(ThisObject);
	WriteCommonProhibitionDateWithDescription();
	
EndProcedure

&AtClient
Procedure PermissionDaysCountOnChange(Item)
	
	CommonProhibitionDateWithDescriptionOnChange(ThisObject);
	WriteCommonProhibitionDateWithDescription();
	
EndProcedure

&AtClient
Procedure PermissionDaysCountAutoCompleteText(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	If IsBlankString(Text) Then
		Return;
	EndIf;
	
	PermissionDaysCount = Text;
	
	CommonProhibitionDateWithDescriptionOnChange(ThisObject);
	WriteCommonProhibitionDateWithDescription();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersUsers

&AtClient
Procedure UsersChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	Items.Users.ChangeRow();
	
EndProcedure

&AtClient
Procedure UsersOnActivateRow(Item)
	
	AttachIdleHandler("UpdateUserDataWaitingHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure UsersRestoreCurrentRowAfterRefusalOnActivateRow()
	
	Items.Users.CurrentRow = UsersCurrentRow;
	
EndProcedure

&AtClient
Procedure UsersBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	// Copying is not required as users can not be repeated.
	If Copy Then
		Cancel = True;
		Return;
	EndIf;
	
	If UsersContinueAdding <> True Then
		Cancel = True;
		UnsavedRecordsChecking(
			New NotifyDescription("UsersBeforeAddingStartEnd", ThisObject));
		Return;
	EndIf;
	
	UsersContinueAdding = Undefined;
	
	ProhibitionDates.GetItems().Clear();
	
EndProcedure

&AtClient
Procedure UsersBeforeRowChange(Item, Cancel)
	
	CurrentData = Item.CurrentData;
	Field          = Item.CurrentItem;
	
	If CurrentData.User = ValueForAllUsers Then
		// Predefined value "<For all users>" does not change.
		If Field = Items.UsersFullPresentation Then
			CommonUseClientServer.MessageToUser(
				MessageTextValueForAllUsersNotChange());
			
		ElsIf Field = Items.UsersComment Then
			CommonUseClientServer.MessageToUser(
				MessageTextCommentForAllUsersNotChange());
		EndIf;
		Cancel = True;
	ElsIf Field <> Items.UsersFullPresentation
	        AND Not ValueIsFilled(CurrentData.Presentation) Then
		// All values except for the predefined value
		// "<For all users>" should be filled in before setting description or prohibition date.
		Item.CurrentItem = Items.UsersFullPresentation;
		CommonUseClientServer.MessageToUser(
			MessageTextFirstSelectUser());
	EndIf;
	
	If Cancel Then
		Items.UsersFullPresentation.ReadOnly = False;
		Items.UsersComment.ReadOnly = False;
	Else
		Items.UsersComment.ReadOnly =
			Not ValueIsFilled(CurrentData.Presentation);
		
		If ValueIsFilled(CurrentData.Presentation) Then
			LockSetOfUserRecords(CurrentData.User, Item.CurrentRow);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
	If Items.Users.SelectedRows.Count() > 1 Then
		ShowMessageBox(, MessageTextForDeletingSelectOneRow());
		Return;
	EndIf;
	
	CurrentData = Items.Users.CurrentData;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CurrentData", CurrentData);
	
	// Item for all users is always present.
	AdditionalParameters.Insert("ProhibitionDatesForAllUsers",
		CurrentData.User = ValueForAllUsers);
	
	If ValueIsFilled(CurrentData.Presentation)
	   AND Not CurrentData.WithoutProhibitionDate Then
		// To remove users with records, confirmation is required.
		If AdditionalParameters.ProhibitionDatesForAllUsers Then
			QuestionText = QuestionTextDeleteProhibitionDatesForAllUsers();
		Else
			If TypeOf(CurrentData.User) = Type("CatalogRef.Users") Then
				QuestionText = QuestionTextDeleteProhibitionDatesForUser();
				
			ElsIf TypeOf(CurrentData.User) = Type("CatalogRef.UsersGroups") Then
				QuestionText = QuestionTextDeleteProhibitionDatesForUsersGroups();
				
			ElsIf TypeOf(CurrentData.User) = Type("CatalogRef.ExternalUsers") Then
				QuestionText = QuestionTextDeleteProhibitionDatesForExternalUser();
				
			ElsIf TypeOf(CurrentData.User) = Type("CatalogRef.ExternalUsersGroups") Then
				QuestionText = QuestionTextDeleteProhibitionDatesForExternalUsersGroups();
			Else
				QuestionText = QuestionTextDeleteProhibitionDates();
			EndIf;
		EndIf;
		
		ShowQueryBox(
			New NotifyDescription(
				"UsersBeforeDeletingConfirmation", ThisObject, AdditionalParameters),
			QuestionText, QuestionDialogMode.YesNo);
		
	Else
		UsersBeforeDeletingContinue(Undefined, AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnStartEdit(Item, NewRow, Copy)
	
	CurrentData = Items.Users.CurrentData;
	
	If Not ValueIsFilled(CurrentData.Presentation) Then
		CurrentData.PictureNumber = -1;
		AttachIdleHandler("IdleHandlerSelectUsers", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnEditEnd(Item, NewRow, CancelEdit)
	
	If SetLocks.Count() > 0 Then
		UnlockAllRecords(ThisObject);
	EndIf;
	
	Items.UsersFullPresentation.ReadOnly = False;
	Items.UsersComment.ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UsersChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	UsersChoiceProcessingAtServer(ValueSelected);
	
EndProcedure

&AtServer
Procedure UsersChoiceProcessingAtServer(ValueSelected)
	
	Filter = New Structure("User");
	
	For Each Value IN ValueSelected Do
		Filter.User = Value;
		If ProhibitionDatesUsers.FindRows(Filter).Count() = 0 Then
			LockAndRecordEmptyDates(
				SectionEmptyRef, SectionEmptyRef, Filter.User, "");
			
			UserDetails = ProhibitionDatesUsers.Add();
			UserDetails.User  = Filter.User;
			
			UserDetails.Presentation = UserPresentationText(
				ThisObject, Filter.User);
			
			UserDetails.FullPresentation = UserDetails.Presentation;
		EndIf;
	EndDo;
	
	FillProhibitionDatesUserPictureNumbers();
	
	UnlockAllRecords(ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handler of the FullPresentation item events of the Users form table.

&AtClient
Procedure UsersFullPresentationOnChange(Item)
	
	CurrentData = Items.Users.CurrentData;
	
	If Not ValueIsFilled(CurrentData.FullPresentation) Then
		CurrentData.FullPresentation = CurrentData.Presentation;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Users.CurrentData;
	If CurrentData.User = ValueForAllUsers Then
		// Item for all users is always present.
		ShowMessageBox(, MessageTextValueForAllUsersNotChange());
	Else
		// A user can be replaced with themselves and with a user that is not selected in the list.
		SelectSelectUsers();
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueIsFilled(Items.Users.CurrentData.User) Then
		ShowValue(, Items.Users.CurrentData.User);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Users.CurrentData;
	If CurrentData.User = ValueSelected Then
		CurrentData.FullPresentation = CurrentData.Presentation;
		Return;
	EndIf;
	
	// A user can be replaced
	// only with another user that is not in the list yet.
	Filter = New Structure("User", ValueSelected);
	Rows = ProhibitionDatesUsers.FindRows(Filter);
	
	If Rows.Count() = 0 Then
		If Not ReplaceUserOfRecordSet(CurrentUser, ValueSelected) Then
			ShowMessageBox(,
				MessageTextValueAlreadyAddedToList()
				+ Chars.LF
				+ MessageTextUpdateFormF5Data());
			Return;
		EndIf;
		// Set the selected user.
		CurrentUser = Undefined;
		CurrentData.User  = ValueSelected;
		CurrentData.Presentation = UserPresentationText(ThisObject, ValueSelected);
		CurrentData.FullPresentation = CurrentData.Presentation;
		Items.UsersComment.ReadOnly = False;
		FillProhibitionDatesUserPictureNumbers(Items.Users.CurrentRow);
		Items.Users.EndEditRow(False);
		UpdateUserData(False);
		NotifyChanged(Type("InformationRegisterRecordKey.ChangeProhibitionDates"));
		Items.Users.CurrentItem = Items.UsersComment;
		Items.Users.ChangeRow();
	Else
		ShowMessageBox(, MessageTextValueAlreadyAddedToList());
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationAutoCompleteText(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = FormDataOfUserChoice(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = FormDataOfUserChoice(Text);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handler of the Comment item events of the Users form table.

&AtClient
Procedure UsersCommentOnChange(Item)
	
	CurrentData = Items.Users.CurrentData;
	
	WriteComment(CurrentData.User, CurrentData.Comment);
	NotifyChanged(Type("InformationRegisterRecordKey.ChangeProhibitionDates"));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersProhibitionDates

&AtClient
Procedure ProhibitionDatesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	Items.ProhibitionDates.ChangeRow();
	
EndProcedure

&AtClient
Procedure ProhibitionDatesOnActivateRow(Item)
	
	ProhibitionDatesSetCommandEnabled(Items.ProhibitionDates.CurrentData <> Undefined);
	
EndProcedure

&AtClient
Procedure ProhibitionDatesBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy
	 OR AllSectionsWithoutObjects
	 OR ProhibitionDateSpecifiedMode = "BySections" Then
		//
		Cancel = True;
		Return;
	EndIf;
	
	If CurrentUser = Undefined Then
		CommonUseClientServer.MessageToUser(MessageTextFirstSelectUser());
		Cancel = True;
		Return;
	EndIf;
	
	CurrentSection = CurrentSection(, True);
	If CurrentSection = SectionEmptyRef Then
		ShowMessageBox(, MessageTextInSelectedSectionProhibitionDatesForObjectNotSet());
		Cancel = True;
		Return;
	EndIf;
	
	Filter = New Structure("Section", CurrentSection);
	FoundStrings = SectionObjectsTypes.FindRows(Filter);
	
	CurrentData = Items.ProhibitionDates.CurrentData;
	
	If FoundStrings.Count() > 0 
	   AND FoundStrings[0].ObjectTypes.Count() > 0 Then
		If ShowCurrentUserSections Then
			Parent = CurrentData.GetParent();
			If Not CurrentData.ThisIsSection
			      AND Parent <> Undefined Then
				// Add object to the section.
				Cancel = True;
				Item.CurrentRow = Parent.GetID();
				Item.AddLine();
			EndIf;
		ElsIf Item.CurrentRow <> Undefined Then
			Cancel = True;
			Item.CurrentRow = Undefined;
			Item.AddLine();
		EndIf;
	Else
		ShowMessageBox(, MessageTextInSelectedSectionProhibitionDatesForObjectNotSet());
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProhibitionDatesBeforeRowChange(Item, Cancel)
	
	CurrentData = Item.CurrentData;
	Field = Items.ProhibitionDates.CurrentItem;
	
	SectionWithoutObjects = SectionsWithoutObjects.FindByValue(CurrentData.Section) <> Undefined;
	
	// Go to the available field or open the form.
	OpenProhibitionDateEditingForm = False;
	OpenSectionsChoiceForm = False;
	
	If Field = Items.ProhibitionDatesFullPresentation Then
		If CurrentData.ThisIsSection Then
			If PurposeForAll(CurrentUser) Then
				// All sections are always filled in, they should not be changed.
				If CurrentData.ProhibitionDateDescription <> "Custom"
				 OR Field = Items.ProhibitionDatesProhibitionDateDescriptionPresentation Then
					OpenProhibitionDateEditingForm = True;
				Else
					CurrentItem = Items.ProhibitionDatesProhibitionDate;
					If Not ValueIsFilled(CurrentData.Section) Then
						CommonUseClientServer.MessageToUser(
							MessageTextCommonDateCanBeSet());
					ElsIf SectionWithoutObjects Then
						CommonUseClientServer.MessageToUser(
							MessageTextSectionsAlreadyFilledCanSetProhibitionDatesForSections());
					Else
						CommonUseClientServer.MessageToUser(
							MessageTextSectionsAlreadyFilledCanSetProhibitionDatesForSectionsAndObjects());
					EndIf;
				EndIf;
			Else
				OpenSectionsChoiceForm = True;
			EndIf;
			
		ElsIf ValueIsFilled(CurrentData.Presentation) Then
			If CurrentData.ProhibitionDateDescription <> "Custom"
			 OR Field = Items.ProhibitionDatesProhibitionDateDescriptionPresentation Then
				OpenProhibitionDateEditingForm = True;
			Else
				CommonUseClientServer.MessageToUser(
					MessageTextObjectAlreadySelectedCanSetProhibitionDate());
				CurrentItem = Items.ProhibitionDatesProhibitionDate;
			EndIf;
		EndIf;
	Else
		If Not ValueIsFilled(CurrentData.Presentation) Then
			// Before you change the description
			// or the prohibition date, it is required to fill in an object, otherwise, you can not write to the register.
			CurrentItem = Items.ProhibitionDatesFullPresentation;
			CommonUseClientServer.MessageToUser(MessageTextFirstSelectObject());
			//
		ElsIf CurrentData.ProhibitionDateDescription <> "Custom"
			  OR Field = Items.ProhibitionDatesProhibitionDateDescriptionPresentation Then
			OpenProhibitionDateEditingForm = True;
		Else
			CurrentItem = Items.ProhibitionDatesProhibitionDate;
		EndIf;
	EndIf;
	
	// Lock record before editing.
	If ValueIsFilled(CurrentData.Presentation) Then
		ReadProperties = LockUserRecord(
			ThisObject, CurrentSection(), CurrentData.Object, CurrentUser);
		
		UpdateReadPropertiesValues(
			CurrentData, ReadProperties, Items.Users.CurrentData);
	EndIf;
	
	If OpenProhibitionDateEditingForm Then
		Cancel = True;
		EditProhibitionDateInForm();
		
	ElsIf OpenSectionsChoiceForm Then
		Cancel = True;
		ChooseSections();
	EndIf;
	
	If Cancel Then
		Items.ProhibitionDatesFullPresentation.ReadOnly = False;
		Items.ProhibitionDatesProhibitionDateDescriptionPresentation.ReadOnly = False;
		Items.ProhibitionDatesProhibitionDate.ReadOnly = False;
	Else
		// Lock unavailable fields.
		Items.ProhibitionDatesFullPresentation.ReadOnly =
			ValueIsFilled(CurrentData.Presentation);
		
		Items.ProhibitionDatesProhibitionDateDescriptionPresentation.ReadOnly = True;
		Items.ProhibitionDatesProhibitionDate.ReadOnly =
			    Not ValueIsFilled(CurrentData.Presentation)
			OR CurrentData.ProhibitionDateDescription <> "Custom";
	EndIf;
	
EndProcedure

&AtClient
Procedure ProhibitionDatesBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
	If Items.ProhibitionDates.SelectedRows.Count() > 1 Then
		ShowMessageBox(, MessageTextForDeletingSelectOneRow());
		Return;
	EndIf;
	
	CurrentData = Items.ProhibitionDates.CurrentData;
	
	If CurrentData.ThisIsSection Then
		If ValueIsFilled(CurrentData.Section) Then
			If CurrentData.GetItems().Count() > 0 Then
				QuestionText = QuestionTextDeleteProhibitionDatesForSectionAndObjects();
			Else
				QuestionText = QuestionTextDeleteProhibitionDatesForSection();
			EndIf;
		Else
			QuestionText = QuestionTextDeleteCommonProhibitionDate();
		EndIf;
	Else
		QuestionText = QuestionTextDeleteObjectProhibitionDate();
	EndIf;
	
	Delete = True;
	
	If CurrentData.ThisIsSection Then
		If PurposeForAll(CurrentUser) Then
			Delete = False;
		EndIf;
		SectionItems = CurrentData.GetItems();
		
		If ProhibitionDateIsSet(CurrentData, CurrentUser)
		 OR SectionItems.Count() > 0 Then
			// Delete prohibition date for the section (i.e. for all objects of the section).
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("CurrentData", CurrentData);
			AdditionalParameters.Insert("SectionItems", SectionItems);
			AdditionalParameters.Insert("Delete", Delete);
			
			ShowQueryBox(
				New NotifyDescription(
					"ProhibitionDatesBeforeDeletingSectionContinue", ThisObject, AdditionalParameters),
				QuestionText, QuestionDialogMode.YesNo);
			Return;
		Else
			If ValueIsFilled(CurrentData.Section) Then
				MessageText = MessageTextForAllUsersSectionsAlwaysShow()
					+ Chars.LF
					+ MessageTextWhenDeletingProhibitionDateCleared();
			Else
				MessageText = MessageTextForAllUsersCommonDateAlwaysShow()
					+ Chars.LF
					+ MessageTextWhenDeletingProhibitionDateCleared();
			EndIf;
			If Delete Then
				ShowMessageBox(
					New NotifyDescription(
						"ProhibitionDatesOnDeleting", ThisObject, CurrentData),
					MessageText);
			Else
				ShowMessageBox(, MessageText);
			EndIf;
			Return;
		EndIf;
	Else
		If ValueIsFilled(CurrentData.Presentation)
		   AND (CurrentData.WriteExist
		      Or ProhibitionDateIsSet(CurrentData, CurrentUser)) Then
			// Delete prohibition date for object by section.
			
			ShowQueryBox(
				New NotifyDescription(
					"ProhibitionDatesBeforeDeletingObjectContinue", ThisObject, CurrentData),
				QuestionText, QuestionDialogMode.YesNo);
			Return;
		EndIf;
	EndIf;
	
	If Delete Then
		ProhibitionDatesOnDeleting(CurrentData);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProhibitionDatesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		If Not Items.ProhibitionDates.CurrentData.ThisIsSection Then
			Items.ProhibitionDates.CurrentData.Section = CurrentSection(, True);
		EndIf;
		If PurposeForAll(CurrentUser)
		 OR Not Items.ProhibitionDates.CurrentData.ThisIsSection Then
			Items.ProhibitionDates.CurrentData.ProhibitionDateDescription = "Custom";
		EndIf;
		Items.ProhibitionDates.CurrentData.ProhibitionDateDescriptionPresentation =
			PresentationOfProhibitionDateDescription(Items.ProhibitionDates.CurrentData);
		
		AttachIdleHandler("IdleHandlerSelectObjects", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProhibitionDatesOnEditEnd(Item, NewRow, CancelEdit)
	
	CurrentData = Items.ProhibitionDates.CurrentData;
	
	If CurrentUser <> Undefined Then
		WriteDescriptionAndProhibitionDate(CurrentData);
	EndIf;
	
	If SetLocks.Count() > 0 Then
		UnlockAllRecords(ThisObject);
	EndIf;
	
	Items.ProhibitionDatesFullPresentation.ReadOnly = False;
	Items.ProhibitionDatesProhibitionDateDescriptionPresentation.ReadOnly = False;
	Items.ProhibitionDatesProhibitionDateDescriptionPresentation.ReadOnly = False;
	
	UpdateExistsProhibitionDatesOfCurrentUser();
	
EndProcedure

&AtClient
Procedure ProhibitionDatesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.ProhibitionDates.CurrentData;
	
	If CurrentData <> Undefined
	   AND CurrentData.Object = ValueSelected Then
		
		Return;
	EndIf;
	
	SectionID = Undefined;
	
	If ShowCurrentUserSections Then
		Parent = CurrentData.GetParent();
		If Parent = Undefined Then
			ObjectsCollection    = CurrentData.GetItems();
			SectionID = CurrentData.GetID();
		Else
			ObjectsCollection    = Parent.GetItems();
			SectionID = Parent.GetID();
		EndIf;
	Else
		ObjectsCollection = ProhibitionDates.GetItems();
	EndIf;
	
	If TypeOf(ValueSelected) = Type("Array") Then
		Objects = ValueSelected;
	Else
		Objects = New Array;
		Objects.Add(ValueSelected);
	EndIf;
	
	ObjectsToAdd = New Array;
	For Each Object IN Objects Do
		ValueNotFound = True;
		For Each String IN ObjectsCollection Do
			If String.Object = Object Then
				ValueNotFound = False;
				Break;
			EndIf;
		EndDo;
		If ValueNotFound Then
			ObjectsToAdd.Add(Object);
		EndIf;
	EndDo;
	
	If ObjectsToAdd.Count() > 0 Then
		
		If CurrentUser <> Undefined Then
			Comment = CurrentUserComment(ThisObject);
			
			LockAndRecordEmptyDates(
				CurrentSection(, True), ObjectsToAdd, CurrentUser, Comment);
			
			NotifyChanged(Type("InformationRegisterRecordKey.ChangeProhibitionDates"));
		EndIf;
		
		For Each CurrentObject IN ObjectsToAdd Do
			ObjectDescription = ObjectsCollection.Add();
			ObjectDescription.Section        = CurrentSection(, True);
			ObjectDescription.Object        = Object;
			ObjectDescription.Presentation = String(Object);
			ObjectDescription.FullPresentation = ObjectDescription.Presentation;
			ObjectDescription.ProhibitionDateDescription = "Custom";
			
			ObjectDescription.ProhibitionDateDescriptionPresentation =
				PresentationOfProhibitionDateDescription(ObjectDescription);
		EndDo;
		
		If SectionID <> Undefined Then
			Items.ProhibitionDates.Expand(SectionID, True);
		EndIf;
	EndIf;
	
	UpdateExistsProhibitionDatesOfCurrentUser();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the FullPresentation item events of the ProhibitionDate form table.

&AtClient
Procedure ProhibitionDatesFullPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectPickObjects();
	
EndProcedure

&AtClient
Procedure ProhibitionDatesFullPresentationClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ProhibitionDatesFullPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.ProhibitionDates.CurrentData;
	
	If CurrentData.Object = ValueSelected Then
		Return;
	EndIf;
	
	// Object can be replaced only with another object that is not in the list yet.
	If ShowCurrentUserSections Then
		ObjectsCollection = CurrentData.GetParent().GetItems();
	Else
		ObjectsCollection = ProhibitionDates.GetItems();
	EndIf;
	ValueNotFound = True;
	For Each String IN ObjectsCollection Do
		If String.Object = ValueSelected Then
			ValueNotFound = False;
			Break;
		EndIf;
	EndDo;
	
	If ValueNotFound Then
		If CurrentData.Object <> ValueSelected Then
			
			PropertyValues = GetCurrentPropertiesValues(
				CurrentData, Items.Users.CurrentData);
			
			If Not ReplaceObjectInUserRecordAtServer(
						CurrentData.Section,
						CurrentData.Object,
						ValueSelected,
						CurrentUser,
						PropertyValues) Then
				
				ShowMessageBox(,
					MessageTextValueAlreadyAddedToList() +
					Chars.LF +
					MessageTextUpdateFormF5Data());
				Return;
			Else
				UpdateReadPropertiesValues(
					CurrentData, PropertyValues, Items.Users.CurrentData);
				
				NotifyChanged(Type("InformationRegisterRecordKey.ChangeProhibitionDates"));
			EndIf;
		EndIf;
		// Set the selected object.
		CurrentData.Object = ValueSelected;
		CurrentData.Presentation = String(CurrentData.Object);
		CurrentData.FullPresentation = CurrentData.Presentation;
		Items.ProhibitionDates.EndEditRow(False);
		Items.ProhibitionDates.CurrentItem = Items.ProhibitionDatesProhibitionDate;
		Items.ProhibitionDates.ChangeRow();
		
		UpdateExistsProhibitionDatesOfCurrentUser();
	Else
		ShowMessageBox(, MessageTextValueAlreadyAddedToList());
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the ProhibitionDate item events of the ProhibitionDate form table.

&AtClient
Procedure ProhibitionDatesProhibitionDateOnChange(Item)
	
	WriteDescriptionAndProhibitionDate();
	
	UpdateExistsProhibitionDatesOfCurrentUser();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RecalculateDates(Command)
	
	QuestionText = QuestionTextAboutUnsavedData();
	
	If ValueIsFilled(QuestionText) Then
		QuestionText = QuestionText + Chars.LF + QuestionTextRecalculateProhibitionDates();
		ShowQueryBox(
			New NotifyDescription("RecalculateDatesEnd", ThisObject),
			QuestionText,
			QuestionDialogMode.YesNo); 
	EndIf;
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	QuestionText = QuestionTextAboutUnsavedData();
	
	If ValueIsFilled(QuestionText) Then
		QuestionText = QuestionText + Chars.LF + QuestionTextUpdateData();
		
		ShowQueryBox(
			New NotifyDescription("UpdateEnd", ThisObject),
			QuestionText,
			QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure Sections(Command)
	
	ChooseSections();
	
EndProcedure

&AtClient
Procedure PickObjects(Command)
	
	If CurrentUser = Undefined Then
		CommonUseClientServer.MessageToUser(
			MessageTextFirstSelectUser());
		Return;
	EndIf;
	
	SelectPickObjects(True);
	
EndProcedure

&AtClient
Procedure ProhibitionDatesChange(Command)
	
	CurrentData = Items.ProhibitionDates.CurrentData;
	If CurrentData = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	Items.ProhibitionDates.ChangeRow();
	
EndProcedure

&AtClient
Procedure SelectUsers(Command)
	
	SelectSelectUsers(True);
	
EndProcedure

&AtClient
Procedure ProhibitionDatesByUsers(Command)
	
	FormParameters = New Structure;
	
	If Parameters.DataImportingProhibitionDates Then
		ReportFormName = "Report.ImportingProhibitionDates.Form.ReportForm";
	Else
		ReportFormName = "Report.ChangeProhibitionDates.Form.ReportForm";
	EndIf;
	
	OpenForm(ReportFormName, FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ProhibitionDatesBySectionsObjectsForUsers(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("BySectionsObjects", True);
	
	If Parameters.DataImportingProhibitionDates Then
		ReportFormName = "Report.ImportingProhibitionDates.Form.ReportForm";
	Else
		ReportFormName = "Report.ChangeProhibitionDates.Form.ReportForm";
	EndIf;
	
	OpenForm(ReportFormName, FormParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsersFullPresentation.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ProhibitionDatesUsers.FullPresentation");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;

	FilterGroup2 = FilterGroup1.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup2.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	FilterElement = FilterGroup2.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ProhibitionDatesUsers.User");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotInList;
	ValueList = New ValueList;
	ValueList.Add(Enums.ProhibitionDatesPurposeKinds.ForAllUsers);
	ValueList.Add(Enums.ProhibitionDatesPurposeKinds.ForAllDatabases);
	FilterElement.RightValue = ValueList;

	FilterElement = FilterGroup2.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ProhibitionDatesUsers.WithoutProhibitionDate");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("MarkIncomplete", True);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProhibitionDatesFullPresentation.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ProhibitionDates.FullPresentation");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("MarkIncomplete", True);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProhibitionDatesProhibitionDate.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	FilterGroup2 = FilterGroup1.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup2.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	FilterElement = FilterGroup2.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("CurrentUser");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotInList;
	ValueList = New ValueList;
	ValueList.Add(Enums.ProhibitionDatesPurposeKinds.ForAllUsers);
	ValueList.Add(Enums.ProhibitionDatesPurposeKinds.ForAllDatabases);
	FilterElement.RightValue = ValueList;

	FilterElement = FilterGroup2.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ProhibitionDate.ThisSection");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	FilterElement = FilterGroup2.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ProhibitionDates.WithoutProhibitionDate");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	FilterGroup2 = FilterGroup1.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup2.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	FilterElement = FilterGroup2.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ProhibitionDate.ThisSection");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;

	FilterElement = FilterGroup2.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ProhibitionDates.WithoutProhibitionDate");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("MarkIncomplete", True);

EndProcedure

&AtClient
Procedure ProhibitionDateSettingSelectionProcessingContinue(Response, ValueSelected) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ProhibitionDateSetting = ValueSelected;
	ChangeProhibitionDateSetting(ValueSelected, True);
	
EndProcedure

&AtClient
Procedure ProhibitionDateSpecificationMethodSelectionProcessingContinue(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ProhibitionDateSpecifiedMode = AdditionalParameters.ValueSelected;
	
	DeleteUnneededOnChangeProhibitionDateSpecifiedMode(
		AdditionalParameters.ValueSelected,
		CurrentUser,
		ProhibitionDateSetting);
	
	Items.Users.Refresh();
	
	ReadUserData(
		ThisObject,
		AdditionalParameters.ValueSelected,
		AdditionalParameters.Data);
	
EndProcedure

&AtClient
Procedure UsersBeforeAddingStartEnd(Result, NotSpecified) Export
	
	If Result Then
		UsersContinueAdding = True;
		Items.Users.AddRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersBeforeDeletingConfirmation(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DeleteUserRecordSet(AdditionalParameters.CurrentData.User);
	
	If AdditionalParameters.ProhibitionDatesForAllUsers Then
		AdditionalParameters.CurrentData.ProhibitionDate         = '00000000';
		AdditionalParameters.CurrentData.ProhibitionDateDescription = "Custom";
		
		If ProhibitionDateSpecifiedMode = "CommonDate" Then
			ProhibitionDate         = '00000000';
			ProhibitionDateDescription = "Custom";
		EndIf;
		AdditionalParameters.Insert("DataDeleted");
		UpdateExistsProhibitionDatesOfCurrentUser();
	EndIf;
	
	NotifyChanged(Type("InformationRegisterRecordKey.ChangeProhibitionDates"));
	
	UsersBeforeDeletingContinue(Undefined, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure UsersBeforeDeletingContinue(NOTSpecified, AdditionalParameters)
	
	CurrentData = AdditionalParameters.CurrentData;
	
	If AdditionalParameters.ProhibitionDatesForAllUsers Then
		NoAddedRows = Not AdditionalParameters.Property("DataDeleted");
		If ShowCurrentUserSections Then
			For Each SectionDescription IN ProhibitionDates.GetItems() Do
				If ProhibitionDateIsSet(SectionDescription, CurrentUser)
				 OR SectionDescription.GetItems().Count() > 0 Then
					NoAddedRows = False;
					SectionDescription.ProhibitionDate         = '00000000';
					SectionDescription.ProhibitionDateDescription = "";
					SectionDescription.GetItems().Clear();
				EndIf;
			EndDo;
		Else
			If ProhibitionDates.GetItems().Count() > 0 Then
				NoAddedRows = False;
				ProhibitionDates.GetItems().Clear();
			EndIf;
		EndIf;
		CurrentData.WithoutProhibitionDate = True;
		CurrentData.FullPresentation = CurrentData.Presentation;
		If NoAddedRows Then
			ShowMessageBox(, MessageTextForAllUsersProhibitionDatesIsNotSet());
		EndIf;
		Return;
	EndIf;
	
	ProhibitionDateSpecifiedMode = Undefined;
	
	UsersOnDeleting();
	
EndProcedure

&AtClient
Procedure UsersOnDeleting()
	
	IndexOf = ProhibitionDatesUsers.IndexOf(ProhibitionDatesUsers.FindByID(
		Items.Users.CurrentRow));
	
	ProhibitionDatesUsers.Delete(IndexOf);
	
	If ProhibitionDatesUsers.Count() <= IndexOf AND IndexOf > 0 Then
		IndexOf = IndexOf -1;
	EndIf;
	
	If ProhibitionDatesUsers.Count() > 0 Then
		Items.Users.CurrentRow =
			ProhibitionDatesUsers[IndexOf].GetID();
	EndIf;
	
EndProcedure

&AtClient
Procedure ProhibitionDatesBeforeDeletingSectionContinue(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	CurrentData   = AdditionalParameters.CurrentData;
	SectionItems = AdditionalParameters.SectionItems;
	
	SectionObjects = New Array;
	SectionObjects.Add(CurrentData.Section);
	
	For Each DataItem IN SectionItems Do
		SectionObjects.Add(DataItem.Object);
	EndDo;
	
	DeleteUserRecord(CurrentData.Section, SectionObjects, CurrentUser);
	
	SectionItems.Clear();
	CurrentData.ProhibitionDate         = '00000000';
	CurrentData.ProhibitionDateDescription = "Custom";
	
	If AdditionalParameters.Delete Then
		ProhibitionDatesOnDeleting(CurrentData);
	Else
		CurrentData.ProhibitionDateDescriptionPresentation =
			PresentationOfProhibitionDateDescription(CurrentData);
	EndIf;
	
	NotifyChanged(Type("InformationRegisterRecordKey.ChangeProhibitionDates"));
	
EndProcedure

&AtClient
Procedure ProhibitionDatesBeforeDeletingObjectContinue(Response, CurrentData) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DeleteUserRecord(
		CurrentSection(),
		CurrentData.Object,
		CurrentUser);
	
	ProhibitionDatesOnDeleting(CurrentData);
	
	NotifyChanged(Type("InformationRegisterRecordKey.ChangeProhibitionDates"));
	
EndProcedure

&AtClient
Procedure ProhibitionDatesOnDeleting(CurrentData) Export
	
	CurrentParent = CurrentData.GetParent();
	If CurrentParent = Undefined Then
		ProhibitionDatesItems = ProhibitionDates.GetItems();
	Else
		ProhibitionDatesItems = CurrentParent.GetItems();
	EndIf;
	
	IndexOf = ProhibitionDatesItems.IndexOf(CurrentData);
	
	ProhibitionDatesItems.Delete(IndexOf);
	
	If ProhibitionDatesItems.Count() <= IndexOf AND IndexOf > 0 Then
		IndexOf = IndexOf -1;
	EndIf;
	
	If ProhibitionDatesItems.Count() > 0 Then
		Items.ProhibitionDates.CurrentRow =
			ProhibitionDatesItems[IndexOf].GetID();
		
	ElsIf CurrentParent <> Undefined Then
		Items.ProhibitionDates.CurrentRow =
			CurrentParent.GetID();
	EndIf;
	
EndProcedure

&AtClient
Procedure RecalculateDatesEnd(Response, NotSpecified) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ResultDescription = RecalculateDatesAtServer();
	
	UpdateAtServer();
	ExpandUserData();
	
	ShowMessageBox(, ResultDescription);
	
EndProcedure

&AtClient
Procedure UpdateEnd(Response, NotSpecified) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	UpdateAtServer();
	ExpandUserData();
	
EndProcedure

&AtServer
Function RecalculateDatesAtServer()
	
	ResultDescription = "";
	ChangeProhibitionDatesService.RecalculateCurrentValuesOfRelativeProhibitionDates(
		False, ResultDescription);
	
	UpdateAtServer();
	
	Return ResultDescription;
	
EndFunction

&AtServer
Procedure UpdateAtServer()
	
	// Calculate prohibition date setting.
	ProhibitionDateSetting = ProhibitionDateCurrentSetting(Parameters.DataImportingProhibitionDates);
	// Set visible by the prohibition date calculated setting.
	SetVisible();
	
	// Caching the current date on the server.
	CurrentDateAtServer = CurrentSessionDate();
	
	OldUser = CurrentUser;
	
	ReadUsers();
	
	Filter = New Structure("User", OldUser);
	FoundStrings = ProhibitionDatesUsers.FindRows(Filter);
	If FoundStrings.Count() = 0 Then
		CurrentUser = ValueForAllUsers;
	Else
		Items.Users.CurrentRow = FoundStrings[0].GetID();
		CurrentUser = OldUser;
	EndIf;
		
	ReadUserData(ThisObject);
	
EndProcedure

&AtClient
Procedure UpdateUserDataWaitingHandler()
	
	UpdateUserData();
	
EndProcedure

&AtClient
Procedure UpdateUserData(CheckUnsavedRecords = True)
	
	CurrentData = Items.Users.CurrentData;
	
	If CurrentData = Undefined
	 OR Not ValueIsFilled(CurrentData.Presentation) Then
		
		NewUser = Undefined;
	Else
		NewUser = CurrentData.User;
	EndIf;
	
	If NewUser = CurrentUser Then
		Return;
	EndIf;
	
	If CheckUnsavedRecords Then
		UnsavedRecordsChecking(New NotifyDescription(
			"UpdateUserDataContinue", ThisObject, NewUser));
	Else
		UpdateUserDataContinue(True, NewUser);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateUserDataContinue(Result, NewUser) Export
	
	If Not Result Then
		AttachIdleHandler(
			"UsersRestoreCurrentRowAfterRefusalOnActivateRow", 0.1, True);
		Return;
	EndIf;
	
	SpecifiedModeValueInList =
		Items.ProhibitionDateSpecifiedMode.ChoiceList.FindByValue(ProhibitionDateSpecifiedMode);
	
	If CurrentUser <> Undefined
	   AND SpecifiedModeValueInList <> Undefined Then
		
		CurrentSpecifiedMode = ProhibitionDateCurrentSpecifiedMode(
			CurrentUser, SingleSection, FirstSection, ValueForAllUsers);
		
		CurrentSpecifiedMode =
			?(ValueIsFilled(CurrentSpecifiedMode), CurrentSpecifiedMode, "CommonDate");
		
		If CurrentSpecifiedMode <> SpecifiedModeValueInList.Value Then
			
			ItemOfList = Items.ProhibitionDateSpecifiedMode.ChoiceList.FindByValue(
				CurrentSpecifiedMode);
			
			ShowQueryBox(
				New NotifyDescription(
					"UpdateUserDataEnd",
					ThisObject,
					NewUser),
				MessageTextSpecifiedModeNotUsed(
					SpecifiedModeValueInList.Presentation,
					?(ItemOfList = Undefined, CurrentSpecifiedMode, ItemOfList.Presentation),
					CurrentUser,
					ThisObject) + Chars.LF + Chars.LF + NStr("en='Continue?';ru='Продолжить?'"),
				QuestionDialogMode.YesNo);
			Return;
		EndIf;
	EndIf;
	
	UpdateUserDataEnd(Undefined, NewUser);
	
EndProcedure

&AtClient
Procedure UpdateUserDataEnd(Response, NewUser) Export
	
	If Response = DialogReturnCode.No Then
		Filter = New Structure("User", CurrentUser);
		FoundStrings = ProhibitionDatesUsers.FindRows(Filter);
		If FoundStrings.Count() > 0 Then
			UsersCurrentRow = FoundStrings[0].GetID();
			AttachIdleHandler(
				"UsersRestoreCurrentRowAfterRefusalOnActivateRow", 0.1, True);
		EndIf;
		Return;
	EndIf;
	
	CurrentUser = NewUser;
	
	// Read the current user data.
	If NewUser = Undefined Then
		ProhibitionDateSpecifiedMode = "CommonDate";
		ProhibitionDates.GetItems().Clear();
		Items.UserData.CurrentPage = Items.UserPageIsNotSelected;
	Else
		ReadUserData(ThisObject);
		ExpandUserData();
	EndIf;
	
	UpdateExistsProhibitionDatesOfCurrentUser();
	
	// Lock the commands Pick, Add (object) until the section is not selected.
	ProhibitionDatesSetCommandEnabled(False);
	
EndProcedure

&AtClient
Procedure UnsavedRecordsChecking(ContinuationProcessor)
	
	Filter = New Structure("User", CurrentUser);
	FoundStrings = ProhibitionDatesUsers.FindRows(Filter);
	
	If FoundStrings.Count() > 0 Then
		QuestionText = QuestionTextAboutUnsavedData(True);
		If ValueIsFilled(QuestionText) Then
			QuestionText = QuestionText + Chars.LF + QuestionTextClearBlankRows();
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("CurrentRow", FoundStrings[0].GetID());
			AdditionalParameters.Insert("ContinuationProcessor", ContinuationProcessor);
			ShowQueryBox(
				New NotifyDescription("UnsavedRecordsCheckingEnd",
					ThisObject,
					AdditionalParameters),
				QuestionText,
				QuestionDialogMode.YesNo);
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(ContinuationProcessor, True);
	
EndProcedure

&AtClient
Procedure UnsavedRecordsCheckingEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		UsersCurrentRow = AdditionalParameters.CurrentRow;
		ExecuteNotifyProcessing(AdditionalParameters.ContinuationProcessor, False);
	Else
		ExecuteNotifyProcessing(AdditionalParameters.ContinuationProcessor, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure ReadUsers()
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("AllSectionsWithoutObjects",     AllSectionsWithoutObjects);
		Query.SetParameter("DataImportingProhibitionDates", Parameters.DataImportingProhibitionDates);
		Query.Text =
		"SELECT DISTINCT
		|	PRESENTATION(ChangeProhibitionDates.User) AS FullPresentation,
		|	ChangeProhibitionDates.User,
		|	CASE
		|		WHEN VALUETYPE(ChangeProhibitionDates.User) = Type(Enum.ProhibitionDatesPurposeKinds)
		|			THEN 0
		|		ELSE 1
		|	END AS CommonUse,
		|	PRESENTATION(ChangeProhibitionDates.User) AS Presentation,
		|	MAX(ChangeProhibitionDates.ProhibitionDate) AS ProhibitionDate,
		|	MAX(ChangeProhibitionDates.ProhibitionDateDescription) AS ProhibitionDateDescription,
		|	MAX(ChangeProhibitionDates.Comment) AS Comment,
		|	FALSE AS WithoutProhibitionDate,
		|	-1 AS PictureNumber
		|FROM
		|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|WHERE
		|	ChangeProhibitionDates.Object <> UNDEFINED
		|	AND (NOT(ChangeProhibitionDates.Section <> ChangeProhibitionDates.Object
		|				AND VALUETYPE(ChangeProhibitionDates.Object) = Type(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections)))
		|	AND (NOT(VALUETYPE(ChangeProhibitionDates.Object) <> Type(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections)
		|				AND &AllSectionsWithoutObjects))
		|
		|GROUP BY
		|	ChangeProhibitionDates.User
		|
		|HAVING
		|	ChangeProhibitionDates.User <> UNDEFINED AND
		|	CASE
		|		WHEN VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.Users)
		|				OR VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.UsersGroups)
		|				OR VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.ExternalUsers)
		|				OR VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.ExternalUsersGroups)
		|				OR ChangeProhibitionDates.User = VALUE(Enum.ProhibitionDatesPurposeKinds.ForAllUsers)
		|			THEN &DataImportingProhibitionDates = FALSE
		|		ELSE &DataImportingProhibitionDates = TRUE
		|	END";
		
		// Incorrect records are excluded from the selection using conditions:
		// - object with the value of CCT type.ChangingProhibitionDatesSections can be only equal to the section.
		Exporting = Query.Execute().Unload();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	// Fill in the full users presentation.
	For Each String IN Exporting Do
		String.Presentation       = UserPresentationText(ThisObject, String.User);
		String.FullPresentation = String.Presentation;
	EndDo;
	
	// Fill in the presentation of all users.
	AllUsersDescription = Exporting.Find(ValueForAllUsers, "User");
	If AllUsersDescription = Undefined Then
		AllUsersDescription = Exporting.Insert(0);
		AllUsersDescription.User = ValueForAllUsers;
		AllUsersDescription.WithoutProhibitionDate = True;
	EndIf;
	AllUsersDescription.Presentation       = PresentationTextForAllUsers(ThisObject);
	AllUsersDescription.FullPresentation = AllUsersDescription.Presentation;
	AllUsersDescription.Comment         = CommentTextForAllUsers();
	
	Exporting.Sort("CommonUse Asc, FullPresentation Asc");
	ValueToFormAttribute(Exporting, "ProhibitionDatesUsers");
	
	FillProhibitionDatesUserPictureNumbers();
	
	CurrentUser = ValueForAllUsers;
	
EndProcedure

&AtClient
Procedure ExpandUserData()
	
	If ShowCurrentUserSections Then
		For Each SectionDescription IN ProhibitionDates.GetItems() Do
			Items.ProhibitionDates.Expand(SectionDescription.GetID(), True);
		EndDo;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure ReadUserData(Context, CurrentSpecifiedMode = Undefined, Data = Undefined)
	
	If Context.ProhibitionDateSetting = "NoProhibition" Then
		
		UnlockAllRecords(Context);
		Return;
		
	ElsIf Context.ProhibitionDateSetting = "ByUsers" Then
		
		FoundStrings = Context.ProhibitionDatesUsers.FindRows(
			New Structure("User", Context.CurrentUser));
		
		If FoundStrings.Count() > 0 Then
			Context.Items.CurrentUserPresentation.Title = FoundStrings[0].Presentation;
		EndIf;
	EndIf;
	
	Context.Items.UserData.CurrentPage =
		Context.Items.PageSelectedUser;
	
	Context.ProhibitionDates.GetItems().Clear();
	
	If CurrentSpecifiedMode = Undefined Then
		CurrentSpecifiedMode = ProhibitionDateCurrentSpecifiedMode(
			Context.CurrentUser,
			Context.SingleSection,
			Context.FirstSection,
			Context.ValueForAllUsers, Data);
		
		CurrentSpecifiedMode = ?(CurrentSpecifiedMode = "", "CommonDate", CurrentSpecifiedMode);
		If Context.ProhibitionDateSpecifiedMode <> CurrentSpecifiedMode Then
			Context.ProhibitionDateSpecifiedMode = CurrentSpecifiedMode;
		EndIf;
	EndIf;
	
	If Context.ProhibitionDateSpecifiedMode = "CommonDate" Then
		Context.Items.SpecificationModes.CurrentPage =
			Context.Items.SpecifiedModeCommonDate;
		
		FillPropertyValues(Context, Data);
		Context.AllowDataChangingToProhibitionDate = Context.PermissionDaysCount <> 0;
		CommonProhibitionDateWithDescriptionOnChange(Context, False);
		Context.Items.ProhibitionDateDescription.ReadOnly = False;
		Context.Items.ProhibitionDate.ReadOnly = False;
		Context.Items.AllowDataChangingToProhibitionDate.ReadOnly = False;
		Context.Items.PermissionDaysCount.ReadOnly = False;
		Try
			LockUserRecord(
				Context,
				Context.SectionEmptyRef,
				Context.SectionEmptyRef,
				Context.CurrentUser,
				True);
		Except
			Context.Items.ProhibitionDateDescription.ReadOnly = True;
			Context.Items.ProhibitionDate.ReadOnly = True;
			Context.Items.AllowDataChangingToProhibitionDate.ReadOnly = True;
			Context.Items.PermissionDaysCount.ReadOnly = True;
			
			CommonUseClientServer.MessageToUser(
				BriefErrorDescription(ErrorInfo()));
		EndTry;
		Return;
	EndIf;
	
	Context.Items.SpecificationModes.CurrentPage =
		Context.Items.SpecifiedModeBySectionsObjects;
	
	SetProhibitionDatesCommandBar(Context);
	
	TransferedParameters = New Structure;
	TransferedParameters.Insert("User",                 Context.CurrentUser);
	TransferedParameters.Insert("FirstSection",                 Context.FirstSection);
	TransferedParameters.Insert("ShowSections",            Context.ShowSections);
	TransferedParameters.Insert("AllSectionsWithoutObjects",        Context.AllSectionsWithoutObjects);
	TransferedParameters.Insert("SectionsWithoutObjects",           Context.SectionsWithoutObjects);
	TransferedParameters.Insert("FormID",           Context.UUID);
	TransferedParameters.Insert("ProhibitionDateSpecifiedMode",    Context.ProhibitionDateSpecifiedMode);
	TransferedParameters.Insert("ValueForAllUsers", Context.ValueForAllUsers);
	TransferedParameters.Insert("LockedRecordsValuesOfKeys", 
		GetLockedRecordsValuesOfKeys(Context));
	
	UserData = Undefined;
	ReadUserDataAtServer(TransferedParameters,
		UserData, Context.ShowCurrentUserSections);
	
	// Import user data to collection.
	RowCollection = Context.ProhibitionDates.GetItems();
	RowCollection.Clear();
	For Each String IN UserData Do
		NewRow = RowCollection.Add();
		FillPropertyValues(NewRow, String.Value);
		NewRow.ProhibitionDateDescriptionPresentation = PresentationOfProhibitionDateDescription(NewRow);
		SubstringsCollection = NewRow.GetItems();
		
		For Each Substring IN String.Value.SubstringsList Do
			NewSubstring = SubstringsCollection.Add();
			FillPropertyValues(NewSubstring, Substring.Value);
			FillByInnerDescriptionProhibitionDates(
				NewSubstring, NewSubstring.ProhibitionDateDescription);
			
			NewSubstring.ProhibitionDateDescriptionPresentation =
				PresentationOfProhibitionDateDescription(NewSubstring);
		EndDo;
		
		If NewRow.ThisIsSection Then
			NewRow.SectionWithoutObjects =
				Context.SectionsWithoutObjects.FindByValue(NewRow.Section) <> Undefined;
		EndIf;
	EndDo;
	
	// Setting of the ProhibitionDate form field.
	If Context.ShowCurrentUserSections Then
		If Context.AllSectionsWithoutObjects Then
			// Only data by the Section dimension is used.
			// The Object dimension is filled in with the Section dimension value.
			// Object is not required to be displayed.
			Context.Items.ProhibitionDatesFullPresentation.Title = SectionTitleText();
			Context.Items.ProhibitionDates.Representation = TableRepresentation.List;
			
		Else
			Context.Items.ProhibitionDatesFullPresentation.Title =
				SectionWithObjectsTitleText();
			
			Context.Items.ProhibitionDates.Representation = TableRepresentation.Tree;
		EndIf;
	Else
		TypesOfObjectsPresentation = "";
		For Each ObjectTypeDescription IN Context.SectionObjectsTypes[0].ObjectTypes Do
			TypesOfObjectsPresentation =
				TrimAll(TypesOfObjectsPresentation + Chars.LF + ObjectTypeDescription.Presentation);
		EndDo;
		Context.Items.ProhibitionDatesFullPresentation.Title = TypesOfObjectsPresentation;
		Context.Items.ProhibitionDates.Representation = TableRepresentation.List;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ReadUserDataAtServer(Val Context, UserData, ShowCurrentUserSections)
	
	SetPrivilegedMode(True);
	
	UnlockAllRecordsAtServer(Context.LockedRecordsValuesOfKeys, Context.FormID);
	
	ShowCurrentUserSections
			  = Context.ShowSections
			OR Context.ProhibitionDateSpecifiedMode = "BySections"
			OR Context.ProhibitionDateSpecifiedMode = "BySectionsAndObjects";
	
	// Prepare the tree of changing prohibition date values.
	If ShowCurrentUserSections Then
		ReadProhibitionDates = ReadUserDataWithSections(
			Context.User,
			Context.AllSectionsWithoutObjects,
			Context.SectionsWithoutObjects,
			Context.ValueForAllUsers);
	Else
		ReadProhibitionDates = ReadUserDataWithoutSections(
			Context.User, Context.FirstSection, Context.ValueForAllUsers);
	EndIf;
	
	UserData = New ValueList;
	RowFields = "FullPresentation, Presentation,
	             |Section, Object, ProhibitionDate,
	             |ProhibitionDateDescription, PermissionDaysCount, WithoutProhibitionDate, ThisIsSection, SubstringsList, WriteExist";
	
	For Each String IN ReadProhibitionDates.Rows Do
		StringStructure = New Structure(RowFields);
		FillPropertyValues(StringStructure, String);
		StringStructure.SubstringsList = New ValueList;
		For Each Substring IN String.Rows Do
			SubstringStructure = New Structure(RowFields);
			FillPropertyValues(SubstringStructure, Substring);
			StringStructure.SubstringsList.Add(SubstringStructure);
		EndDo;
		UserData.Add(StringStructure);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function ReadUserDataWithSections(Val User,
                                              Val AllSectionsWithoutObjects,
                                              Val SectionsWithoutObjects,
                                              Val ValueForAllUsers)
	
	// Prepare the tree of changing
	// prohibition date values with the first level by sections.
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("User",                 User);
		Query.SetParameter("AllSectionsWithoutObjects",        AllSectionsWithoutObjects);
		Query.SetParameter("CommonDatePresentation",       PresentationCommonDateText());
		Query.SetParameter("ValueForAllUsers", ValueForAllUsers);
		Query.Text =
		"SELECT DISTINCT
		|	Sections.Ref,
		|	Sections.Presentation,
		|	Sections.Predefined
		|INTO Sections
		|FROM
		|	(SELECT
		|		VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef) AS Ref,
		|		&CommonDatePresentation AS Presentation,
		|		FALSE AS Predefined
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ChangingProhibitionDatesSections.Ref,
		|		ChangingProhibitionDatesSections.Description,
		|		NULL
		|	FROM
		|		ChartOfCharacteristicTypes.ChangingProhibitionDatesSections AS ChangingProhibitionDatesSections
		|	WHERE
		|		ChangingProhibitionDatesSections.Predefined
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ChangeProhibitionDates.Section,
		|		ChangeProhibitionDates.Section.Description,
		|		NULL
		|	FROM
		|		InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|	WHERE
		|		ChangeProhibitionDates.Section <> VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef)) AS Sections
		|
		|INDEX BY
		|	Sections.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Sections.Ref AS Section,
		|	Sections.Predefined AS Predefined,
		|	Sections.Presentation AS SectionPresentation,
		|	ChangeProhibitionDates.Object,
		|	PRESENTATION(ChangeProhibitionDates.Object) AS FullPresentation,
		|	PRESENTATION(ChangeProhibitionDates.Object) AS Presentation,
		|	CASE
		|		WHEN ChangeProhibitionDates.Object IS NULL 
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS WithoutProhibitionDate,
		|	ChangeProhibitionDates.ProhibitionDate,
		|	ChangeProhibitionDates.ProhibitionDateDescription,
		|	FALSE AS ThisIsSection,
		|	0 AS PermissionDaysCount,
		|	TRUE AS WriteExist
		|FROM
		|	Sections AS Sections
		|		LEFT JOIN InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|		ON Sections.Ref = ChangeProhibitionDates.Section
		|			AND (ChangeProhibitionDates.User = &User)
		|			AND (ChangeProhibitionDates.Object <> UNDEFINED)
		|			AND (NOT(ChangeProhibitionDates.Section <> ChangeProhibitionDates.Object
		|					AND VALUETYPE(ChangeProhibitionDates.Object) = Type(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections)))
		|			AND (NOT(VALUETYPE(ChangeProhibitionDates.Object) <> Type(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections)
		|					AND &AllSectionsWithoutObjects))
		|WHERE
		|	Not(&User <> &ValueForAllUsers
		|				AND ChangeProhibitionDates.Section IS NULL )
		|
		|ORDER BY
		|	Predefined DESC,
		|	SectionPresentation
		|TOTALS
		|	MAX(Predefined),
		|	MAX(SectionPresentation),
		|	MIN(WithoutProhibitionDate),
		|	MAX(ThisIsSection)
		|BY
		|	Section";
		
		ReadProhibitionDates = Query.Execute().Unload(QueryResultIteration.ByGroups);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	For Each String IN ReadProhibitionDates.Rows Do
		String.Presentation = String.SectionPresentation;
		String.Object    = String.Section;
		String.ThisIsSection = True;
		SectionRow = String.Rows.Find(String.Section, "Object");
		If SectionRow <> Undefined Then
			String.WriteExist = True;
			String.ProhibitionDate = SectionRow.ProhibitionDate;
			If ValueIsFilled(SectionRow.ProhibitionDateDescription) Then
				FillByInnerDescriptionProhibitionDates(String, SectionRow.ProhibitionDateDescription);
			Else
				String.ProhibitionDateDescription = "Custom";
			EndIf;
			String.Rows.Delete(SectionRow);
		Else
			If PurposeForAll(User) Then
				String.ProhibitionDateDescription = "Custom";
			EndIf;
			If String.Rows.Count() = 1
			   AND String.Rows[0].Object = Null Then
				
				String.Rows.Delete(String.Rows[0]);
			EndIf;
		EndIf;
		String.FullPresentation = String.Presentation;
	EndDo;
	
	Return ReadProhibitionDates;
	
EndFunction

&AtServerNoContext
Function ReadUserDataWithoutSections(Val User, Val FirstSection, Val ValueForAllUsers)
	
	// Values tree with the first level by objects.
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("User",                 User);
		Query.SetParameter("FirstSection",                 FirstSection);
		Query.SetParameter("CommonDatePresentation",       PresentationCommonDateText());
		Query.SetParameter("ValueForAllUsers", ValueForAllUsers);
		Query.Text =
		"SELECT
		|	VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef) AS Section,
		|	VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef) AS Object,
		|	&CommonDatePresentation AS FullPresentation,
		|	&CommonDatePresentation AS Presentation,
		|	ISNULL(CommonDate.ProhibitionDate, DATETIME(1, 1, 1, 0, 0, 0)) AS ProhibitionDate,
		|	ISNULL(CommonDate.ProhibitionDateDescription, """") AS ProhibitionDateDescription,
		|	TRUE AS ThisIsSection,
		|	0 AS PermissionDaysCount,
		|	TRUE AS WriteExist
		|FROM
		|	(SELECT
		|		TRUE AS TrueValue) AS Value
		|		LEFT JOIN (SELECT
		|			ChangeProhibitionDates.ProhibitionDate AS ProhibitionDate,
		|			ChangeProhibitionDates.ProhibitionDateDescription AS ProhibitionDateDescription
		|		FROM
		|			InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|		WHERE
		|			ChangeProhibitionDates.User = &User
		|			AND ChangeProhibitionDates.Section = VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef)
		|			AND ChangeProhibitionDates.Object = VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef)) AS CommonDate
		|		ON (TRUE)
		|WHERE
		|	CASE
		|			WHEN &User = &ValueForAllUsers
		|				THEN TRUE
		|			ELSE Not CommonDate.ProhibitionDate IS NULL 
		|		END
		|
		|UNION ALL
		|
		|SELECT
		|	&FirstSection,
		|	ChangeProhibitionDates.Object,
		|	PRESENTATION(ChangeProhibitionDates.Object),
		|	PRESENTATION(ChangeProhibitionDates.Object),
		|	ChangeProhibitionDates.ProhibitionDate,
		|	ChangeProhibitionDates.ProhibitionDateDescription,
		|	FALSE,
		|	0,
		|	TRUE
		|FROM
		|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|WHERE
		|	ChangeProhibitionDates.User = &User
		|	AND ChangeProhibitionDates.Section = &FirstSection
		|	AND ChangeProhibitionDates.Object <> UNDEFINED
		|	AND VALUETYPE(ChangeProhibitionDates.Object) <> Type(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections)";
		
		ReadProhibitionDates = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	IndexOf = ReadProhibitionDates.Rows.Count()-1;
	While IndexOf >= 0 Do
		String = ReadProhibitionDates.Rows[IndexOf];
		FillByInnerDescriptionProhibitionDates(String, String.ProhibitionDateDescription);
		IndexOf = IndexOf - 1;
	EndDo;
	
	Return ReadProhibitionDates;
	
EndFunction

&AtServer
Procedure LockSetOfUserRecords(User, CurrentRow = Undefined)
	
	// Before starting to change a comment.
	// Before setting a new selected user.
	// Before deleting the current user string.
	
	If CurrentRow = Undefined Then
		CurrentData = Undefined;
	Else
		CurrentData = ProhibitionDatesUsers.FindByID(CurrentRow);
	EndIf;
	
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("User", User);
		Query.Text =
		"SELECT
		|	ChangeProhibitionDates.Section,
		|	ChangeProhibitionDates.Object,
		|	ChangeProhibitionDates.User,
		|	ChangeProhibitionDates.ProhibitionDate,
		|	ChangeProhibitionDates.ProhibitionDateDescription,
		|	ChangeProhibitionDates.Comment
		|FROM
		|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|WHERE
		|	ChangeProhibitionDates.User = &User";
		
		Exporting = Query.Execute().Unload();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	KeyValuesRecords = New Structure("Section, Object, User");
	
	Try
		For Each RecordDescription IN Exporting Do
			//
			FillPropertyValues(KeyValuesRecords, RecordDescription);
			FoundStrings = SetLocks.FindRows(KeyValuesRecords);
			If FoundStrings.Count() = 0 Then
				// Add a new lock.
				RecordKey = InformationRegisters.ChangeProhibitionDates.CreateRecordKey(
					KeyValuesRecords);
				
				LockDataForEdit(RecordKey, , UUID);
				FillPropertyValues(SetLocks.Add(), KeyValuesRecords);
				If CurrentData <> Undefined Then
					// Rereading of the ProhibitionDate, ProhibitionDateDescription, Comment fields.
					If WithoutSectionsAndObjects Then
						If RecordDescription.Section = SectionEmptyRef
						   AND RecordDescription.Object = SectionEmptyRef Then
							CurrentData.ProhibitionDate       = RecordDescription.ProhibitionDate;
							CurrentData.ProhibitionDateDescription = RecordDescription.ProhibitionDateDescription;
							CurrentData.Comment = RecordDescription.Comment;
						EndIf;
					Else
						CurrentData.Comment = RecordDescription.Comment;
					EndIf;
				EndIf;
			EndIf;
		EndDo;
	Except
		UnlockAllRecords(ThisObject);
		Raise;
	EndTry;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UnlockAllRecords(Val Context)
	
	UnlockAllRecordsAtServer(
		GetLockedRecordsValuesOfKeys(Context), Context.UUID);
	
	Context.SetLocks.Clear();
	
EndProcedure

&AtClientAtServerNoContext
Function GetLockedRecordsValuesOfKeys(Val Context)
	
	ValuesKeys = New Array;
	
	For Each LockDescription IN Context.SetLocks Do
		//
		KeyValuesRecords = New Structure("Section, Object, User");
		FillPropertyValues(KeyValuesRecords, LockDescription);
		ValuesKeys.Add(KeyValuesRecords);
	EndDo;
	
	Return ValuesKeys;
	
EndFunction

&AtServerNoContext
Procedure UnlockAllRecordsAtServer(LockedRecordsValuesOfKeys, FormID)
	
	For Each KeyValuesRecords IN LockedRecordsValuesOfKeys Do
		RecordKey = InformationRegisters.ChangeProhibitionDates.CreateRecordKey(KeyValuesRecords);
		UnlockDataForEdit(RecordKey, FormID);
	EndDo;
	
EndProcedure

&AtServer
Function ReplaceUserOfRecordSet(OldUser, NewUser)
	
	SetPrivilegedMode(True);
	
	If OldUser <> Undefined Then
		LockSetOfUserRecords(OldUser);
	EndIf;
	LockSetOfUserRecords(NewUser);
	
	RecordSet = InformationRegisters.ChangeProhibitionDates.CreateRecordSet();
	RecordSet.Filter.User.Set(NewUser, True);
	RecordSet.Read();
	If RecordSet.Count() > 0 Then
		Return False;
	EndIf;
	
	If OldUser <> Undefined Then
		BeginTransaction();
		Try
			RecordSet.Filter.User.Set(OldUser, True);
			RecordSet.Read();
			UserData = RecordSet.Unload();
			RecordSet.Clear();
			RecordSet.Write();
			
			UserData.FillValues(NewUser, "User");
			RecordSet.Filter.User.Set(NewUser, True);
			RecordSet.Load(UserData);
			RecordSet.Write();
		Except
			RollbackTransaction();
			UnlockAllRecords(ThisObject);
			Raise;
		EndTry;
		CommitTransaction();
	Else
		LockAndRecordEmptyDates(
			SectionEmptyRef, SectionEmptyRef, NewUser, "");
	EndIf;
	
	UnlockAllRecords(ThisObject);
	
	Return True;
	
EndFunction

&AtServer
Procedure DeleteUserRecordSet(User)
	
	SetPrivilegedMode(True);
	
	LockSetOfUserRecords(User);
	
	RecordSet = InformationRegisters.ChangeProhibitionDates.CreateRecordSet();
	RecordSet.Filter.User.Set(User, True);
	RecordSet.Write();
	
	UnlockAllRecords(ThisObject);
	
EndProcedure

&AtServerNoContext
Procedure WriteComment(User, Comment);
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.ChangeProhibitionDates.CreateRecordSet();
	RecordSet.Filter.User.Set(User, True);
	RecordSet.Read();
	UserData = RecordSet.Unload();
	UserData.FillValues(Comment, "Comment");
	RecordSet.Load(UserData);
	RecordSet.Write();
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateReadPropertiesValues(CurrentPropertiesValues, ReadProperties, CommentCurrentData = False)
	
	If ReadProperties.Comment <> Undefined Then
		//
		If CommentCurrentData = False Then
			CurrentPropertiesValues.Comment = ReadProperties.Comment;
			//
		ElsIf CommentCurrentData <> Undefined Then
			CommentCurrentData.Comment = ReadProperties.Comment;
		EndIf;
	EndIf;
	
	If ReadProperties.ProhibitionDate <> Undefined Then
		CurrentPropertiesValues.ProhibitionDate              = ReadProperties.ProhibitionDate;
		CurrentPropertiesValues.ProhibitionDateDescription      = ReadProperties.ProhibitionDateDescription;
		CurrentPropertiesValues.PermissionDaysCount = ReadProperties.PermissionDaysCount;
		CalculatedProperties = New Structure;
		CalculatedProperties.Insert("ProhibitionDateDescriptionPresentation", PresentationOfProhibitionDateDescription(ReadProperties));
		FillPropertyValues(CurrentPropertiesValues, CalculatedProperties);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetCurrentPropertiesValues(CurrentData, CommentCurrentData)
	
	Properties = New Structure;
	Properties.Insert("ProhibitionDate");
	Properties.Insert("ProhibitionDateDescription");
	Properties.Insert("PermissionDaysCount");
	Properties.Insert("Comment");
	
	If CommentCurrentData <> Undefined Then
		Properties.Comment = CommentCurrentData.Comment;
	EndIf;
	
	Properties.ProhibitionDate              = CurrentData.ProhibitionDate;
	Properties.ProhibitionDateDescription      = CurrentData.ProhibitionDateDescription;
	Properties.PermissionDaysCount = CurrentData.PermissionDaysCount;
	
	Return Properties;
	
EndFunction

&AtClientAtServerNoContext
Function LockUserRecord(Val Context, Val Section, Val Object, Val User, Val UnlockPreviouslyLocked = False)
	
	ValuesKeysRecords = New Array;
	//
	If UnlockPreviouslyLocked Then
		For Each LockDescription IN Context.SetLocks Do
			KeyValuesRecords = New Structure("Section, Object, User");
			FillPropertyValues(KeyValuesRecords, LockDescription);
			ValuesKeysRecords.Add(KeyValuesRecords);
		EndDo;
		Context.SetLocks.Clear();
	EndIf;
	
	KeyValuesRecords = New Structure;
	KeyValuesRecords.Insert("Section",       Section);
	KeyValuesRecords.Insert("Object",       Object);
	KeyValuesRecords.Insert("User", User);
	
	ReadProperties = New Structure;
	ReadProperties.Insert("ProhibitionDate");
	ReadProperties.Insert("ProhibitionDateDescription");
	ReadProperties.Insert("PermissionDaysCount");
	ReadProperties.Insert("Comment");
	
	If UnlockPreviouslyLocked
	 OR Context.SetLocks.FindRows(KeyValuesRecords).Count() = 0 Then
		
		ReadProperties = LockUserRecordAtServer(
			KeyValuesRecords,
			Context.UUID,
			ReadProperties,
			UnlockPreviouslyLocked,
			ValuesKeysRecords);
		
		If UnlockPreviouslyLocked Then
			Context.SetLocks.Clear();
		EndIf;
		FillPropertyValues(Context.SetLocks.Add(), KeyValuesRecords);
	EndIf;
	
	Return ReadProperties;
	
EndFunction

&AtServerNoContext
Function LockUserRecordAtServer(Val KeyValuesRecords, Val UUID, Val ReadProperties, Val UnlockPreviouslyLocked, Val ValuesKeysRecords)
	
	If UnlockPreviouslyLocked Then
		UnlockAllRecordsAtServer(ValuesKeysRecords, UUID);
	EndIf;
	
	RecordKey = InformationRegisters.ChangeProhibitionDates.CreateRecordKey(KeyValuesRecords);
	LockDataForEdit(RecordKey, , UUID);
	
	RecordManager = InformationRegisters.ChangeProhibitionDates.CreateRecordManager();
	FillPropertyValues(RecordManager, KeyValuesRecords);
	RecordManager.Read();
	If RecordManager.Selected() Then
		ReadProperties.ProhibitionDate = RecordManager.ProhibitionDate;
		ReadProperties.Comment = RecordManager.Comment;
		FillByInnerDescriptionProhibitionDates(
			ReadProperties, RecordManager.ProhibitionDateDescription);
	Else
		BeginTransaction();
		Try
			Query = New Query;
			Query.SetParameter("User", KeyValuesRecords.User);
			Query.Text =
			"SELECT TOP 1
			|	ChangeProhibitionDates.Comment
			|FROM
			|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
			|WHERE
			|	ChangeProhibitionDates.User = &User";
			Selection = Query.Execute().Select();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		If Selection.Next() Then
			ReadProperties.Comment = Selection.Comment;
		EndIf;
	EndIf;
	
	Return ReadProperties;
	
EndFunction

&AtServer
Function ReplaceObjectInUserRecordAtServer(Val Section, Val OldObject, Val NewObject, Val User, CurrentPropertiesValues)
	
	SetPrivilegedMode(True);
	
	// Lock a new record and check whether it does not exist.
	LockUserRecord(ThisObject, Section, NewObject, User);
	
	KeyValuesRecords = New Structure;
	KeyValuesRecords.Insert("Section",       Section);
	KeyValuesRecords.Insert("Object",       NewObject);
	KeyValuesRecords.Insert("User", User);
	
	RecordManager = InformationRegisters.ChangeProhibitionDates.CreateRecordManager();
	FillPropertyValues(RecordManager, KeyValuesRecords);
	RecordManager.Read();
	If RecordManager.Selected() Then
		UnlockAllRecords(ThisObject);
		Return False;
	EndIf;
	
	If ValueIsFilled(OldObject) Then
		// Old record lock
		ReadProperties = LockUserRecord(
			ThisObject, Section, OldObject, User);
		
		UpdateReadPropertiesValues(CurrentPropertiesValues, ReadProperties);
		
		KeyValuesRecords.Object = OldObject;
		FillPropertyValues(RecordManager, KeyValuesRecords);
		RecordManager.Read();
		If RecordManager.Selected() Then
			RecordManager.Delete();
		EndIf;
	EndIf;
	
	If ValueIsFilled(ProhibitionDate)
	   AND ValueIsFilled(ProhibitionDateDescription) Then
		
		RecordManager.Section              = Section;
		RecordManager.Object              = NewObject;
		RecordManager.User        = User;
		RecordManager.ProhibitionDate         = CurrentPropertiesValues.ProhibitionDate;
		RecordManager.ProhibitionDateDescription = InnerDescriptionProhibitionDates(CurrentPropertiesValues);
		RecordManager.Comment         = CurrentPropertiesValues.Comment;
		
		RecordManager.Write();
	EndIf;
	
	UnlockAllRecords(ThisObject);
	
	Return True;
	
EndFunction

&AtClient
Function CurrentSection(CurrentData = Undefined, SectionOfObjects = False)
	
	If CurrentData = Undefined Then
		CurrentData = Items.ProhibitionDates.CurrentData;
	EndIf;
	
	If WithoutSectionsAndObjects
	 OR ProhibitionDateSpecifiedMode = "CommonDate" Then
		
		CurrentSection = SectionEmptyRef;
		
	ElsIf ShowCurrentUserSections Then
		If CurrentData.ThisIsSection Then
			CurrentSection = CurrentData.Section;
		Else
			CurrentSection = CurrentData.GetParent().Section;
		EndIf;
		
	Else // The single section that is not shown to a user.
		If CurrentData <> Undefined
		   AND CurrentData.Section = SectionEmptyRef
		   AND Not SectionOfObjects Then
			
			CurrentSection = SectionEmptyRef;
		Else
			CurrentSection = FirstSection;
		EndIf;
	EndIf;
	
	Return CurrentSection;
	
EndFunction

&AtClient
Procedure WriteCommonProhibitionDateWithDescription();
	
	// WriteDescriptionAndProhibitionDate
	Data = New Structure;
	Data.Insert("Object",                   SectionEmptyRef);
	Data.Insert("ProhibitionDateDescription",      ProhibitionDateDescription);
	Data.Insert("PermissionDaysCount", PermissionDaysCount);
	Data.Insert("ProhibitionDate",              ProhibitionDate);
	
	WriteDescriptionAndProhibitionDate(Data);
	
EndProcedure

&AtClient
Procedure WriteDescriptionAndProhibitionDate(CurrentData = Undefined)
	
	If CurrentData = Undefined Then
		CurrentData = Items.ProhibitionDates.CurrentData;
	EndIf;
	
	If ProhibitionDateIsSet(CurrentData, CurrentUser) Then
		// Record of the description or prohibition date.
		Comment = CurrentUserComment(ThisObject);
		WriteProhibitionDateWithDescription(
			CurrentSection(CurrentData),
			CurrentData.Object,
			CurrentUser,
			CurrentData.ProhibitionDate,
			InnerDescriptionProhibitionDates(CurrentData),
			Comment);
	Else
		DeleteUserRecord(
			CurrentSection(CurrentData),
			CurrentData.Object,
			CurrentUser);
	EndIf;
	
	NotifyChanged(Type("InformationRegisterRecordKey.ChangeProhibitionDates"));
	
EndProcedure

&AtServerNoContext
Procedure WriteProhibitionDateWithDescription(Val Section, Val Object, Val User, Val ProhibitionDate, Val InnerDescriptionProhibitionDates, Val Comment)
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.ChangeProhibitionDates.CreateRecordManager();
	RecordManager.Section              = Section;
	RecordManager.Object              = Object;
	RecordManager.User        = User;
	RecordManager.ProhibitionDate         = ProhibitionDate;
	RecordManager.ProhibitionDateDescription = InnerDescriptionProhibitionDates;
	RecordManager.Comment = Comment;
	RecordManager.Write();
	
EndProcedure

&AtServer
Procedure DeleteUserRecord(Val Section, Val Object, Val User)
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.ChangeProhibitionDates.CreateRecordManager();
	
	If TypeOf(Object) = Type("Array") Then
		Objects = Object;
	Else
		Objects = New Array;
		Objects.Add(Object);
	EndIf;
	
	For Each CurrentObject IN Objects Do
		LockUserRecord(ThisObject, Section, CurrentObject, User);
	EndDo;
	
	For Each CurrentObject IN Objects Do
		RecordManager.Section = Section;
		RecordManager.Object = CurrentObject;
		RecordManager.User = User;
		RecordManager.Read();
		If RecordManager.Selected() Then
			RecordManager.Delete();
		EndIf;
	EndDo;
	
	UnlockAllRecords(ThisObject);
	
EndProcedure

&AtClient
Procedure UpdateExistsProhibitionDatesOfCurrentUser()
	
	If Items.Users.CurrentData = Undefined Then
		Return;
	EndIf;
	CurrentData = Items.Users.CurrentData;
	
	WithoutProhibitionDate = True;
	If ProhibitionDateSpecifiedMode = "CommonDate" Then
		If PurposeForAll(CurrentUser) Then
			WithoutProhibitionDate = Not ValueIsFilled(CurrentData.ProhibitionDate)
			               AND CurrentData.ProhibitionDateDescription = "Custom";
		Else
			WithoutProhibitionDate = CurrentData.WithoutProhibitionDate;
		EndIf;
	Else
		For Each String IN ProhibitionDates.GetItems() Do
			WithoutProhibitionDateSection = True;
			If ProhibitionDateIsSet(String, CurrentUser) Then
				WithoutProhibitionDateSection = False;
			EndIf;
			For Each SubordinatedRow IN String.GetItems() Do
				If ProhibitionDateIsSet(SubordinatedRow, CurrentUser) Then
					SubordinatedRow.WithoutProhibitionDate = False;
					WithoutProhibitionDateSection = False;
				Else
					SubordinatedRow.WithoutProhibitionDate = True;
				EndIf;
			EndDo;
			String.FullPresentation = String.Presentation;
			String.WithoutProhibitionDate = WithoutProhibitionDateSection;
			WithoutProhibitionDate = WithoutProhibitionDate AND WithoutProhibitionDateSection;
		EndDo;
	EndIf;
	
	CurrentData.WithoutProhibitionDate = WithoutProhibitionDate;
	
EndProcedure

&AtClient
Procedure IdleHandlerSelectUsers()
	
	SelectSelectUsers();
	
EndProcedure

&AtClient
Procedure SelectSelectUsers(Pick = False)
	
	If Parameters.DataImportingProhibitionDates Then
		SelectPickExchangePlansNodes(Pick);
		Return;
	EndIf;
	
	If UseExternalUsers Then
		ShowUsersTypeSelectionOrExternalUsers(
			New NotifyDescription("PickSelectUsersEnd", ThisObject, Pick));
	Else
		PickSelectUsersEnd(False, Pick);
	EndIf;
	
EndProcedure

&AtClient
Procedure PickSelectUsersEnd(SelectionAndPickOutOfExternalUsers, Pick) Export
	
	If SelectionAndPickOutOfExternalUsers = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow",
		?(Items.Users.CurrentData = Undefined,
		  Undefined,
		  Items.Users.CurrentData.User));
	
	If SelectionAndPickOutOfExternalUsers Then
		FormParameters.Insert("ExternalUserGroupChoice", True);
	Else
		FormParameters.Insert("UserGroupChoice", True);
	EndIf;
	
	If Pick Then
		FormParameters.Insert("CloseOnChoice", False);
		FormOwner = Items.Users;
	Else
		FormOwner = Items.UsersFullPresentation;
	EndIf;
	
	If SelectionAndPickOutOfExternalUsers Then
	
		If CatalogExternalUsersEnabled Then
			OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, FormOwner);
		Else
			ShowMessageBox(, MessageTextNotEnoughRightsForChoiceOfExternalUsers());
		EndIf;
	Else
		OpenForm("Catalog.Users.ChoiceForm", FormParameters, FormOwner);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectPickExchangePlansNodes(Pick)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("ChooseAllNodes", True);
	FormParameters.Insert("ExchangePlansForChoice", ListOfUserTypes.UnloadValues());
	FormParameters.Insert("CurrentRow",
		?(Items.Users.CurrentData = Undefined,
		  Undefined,
		  Items.Users.CurrentData.User));
	
	If Pick Then
		FormParameters.Insert("CloseOnChoice", False);
		FormParameters.Insert("Multiselect", True);
		FormOwner = Items.Users;
	Else
		FormOwner = Items.UsersFullPresentation;
	EndIf;
	
	OpenForm("CommonForm.ExchangePlanNodesSelection", FormParameters, FormOwner);
	
EndProcedure

&AtServerNoContext
Function FormDataOfUserChoice(Val Text,
                                             Val IcludingGroups = True,
                                             Val IncludingExternalUsers = Undefined,
                                             Val WithoutUsers = False)
	
	Return Users.FormDataOfUserChoice(
		Text,
		IcludingGroups,
		IncludingExternalUsers,
		WithoutUsers);
	
EndFunction

&AtClient
Procedure ShowUsersTypeSelectionOrExternalUsers(ContinuationProcessor)
	
	SelectionAndPickOutOfExternalUsers = False;
	
	If UseExternalUsers Then
		
		ListOfUserTypes.ShowChooseItem(
			New NotifyDescription(
				"ShowTypeSelectionUsersOrExternalUsersEnd",
				ThisObject,
				ContinuationProcessor),
			TitleTextChoiceDataType(),
			ListOfUserTypes[0]);
	Else
		ExecuteNotifyProcessing(ContinuationProcessor, SelectionAndPickOutOfExternalUsers);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowTypeSelectionUsersOrExternalUsersEnd(SelectedItem, ContinuationProcessor) Export
	
	If SelectedItem <> Undefined Then
		SelectionAndPickOutOfExternalUsers =
			SelectedItem.Value = Type("CatalogRef.ExternalUsers");
		
		ExecuteNotifyProcessing(ContinuationProcessor, SelectionAndPickOutOfExternalUsers);
	Else
		ExecuteNotifyProcessing(ContinuationProcessor, Undefined);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillProhibitionDatesUserPictureNumbers(CurrentRow = Undefined)
	
	If Parameters.DataImportingProhibitionDates Then
		
		For Each String IN ProhibitionDatesUsers Do
			
			If String.User
			   = Enums.ProhibitionDatesPurposeKinds.ForAllDatabases Then
				
				String.PictureNumber = -1;
				
			ElsIf Not ValueIsFilled(String.User) Then
				String.PictureNumber = 0;
				
			ElsIf String.User
			        = CommonUse.ObjectManagerByRef(String.User).ThisNode() Then
				
				String.PictureNumber = 1;
			Else
				String.PictureNumber = 2;
			EndIf;
		EndDo;
	Else
		Users.FillUserPictureNumbers(
			ProhibitionDatesUsers, "User", "PictureNumber", CurrentRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure IdleHandlerSelectObjects()
	
	SelectPickObjects();
	
EndProcedure

&AtClient
Procedure ProhibitionDatesSetCommandEnabled(Val Enabled)
	
	Items.ProhibitionDatesChange.Enabled = Enabled;
	
	If ProhibitionDateSpecifiedMode = "ByObjects" Then
		Enabled = True;
	EndIf;
	
	Items.ProhibitionDatesPick.Enabled = Enabled;
	Items.ProhibitionDatesAdd.Enabled = Enabled;
	
EndProcedure

&AtClient
Procedure SelectPickObjects(Pick = False)
	
	CurrentData = Items.ProhibitionDates.CurrentData;
	
	// Data type choice
	Filter = New Structure("Section", CurrentSection(, True));
	WarningText = MessageTextInSelectedSectionProhibitionDatesForObjectNotSet();
	If Filter.Section = SectionEmptyRef Then
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	TypeList = SectionObjectsTypes.FindRows(Filter)[0].ObjectTypes;
	If TypeList.Count() = 0 Then
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	
	If TypeList.Count() = 1 Then
		PickSelectObjectsEnd(TypeList[0], Pick);
	Else
		TypeList.ShowChooseItem(
			New NotifyDescription("PickSelectObjectsEnd", ThisObject, Pick),
			TitleTextChoiceDataType(),
			TypeList[0]);
	EndIf;
	
EndProcedure

&AtClient
Procedure PickSelectObjectsEnd(Item, Pick) Export
	
	If Item = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items.ProhibitionDates.CurrentData;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow",
		?(CurrentData = Undefined, Undefined, CurrentData.Object));
	
	If Pick Then
		FormParameters.Insert("CloseOnChoice", False);
		FormOwner = Items.ProhibitionDates;
	Else
		FormOwner = Items.ProhibitionDatesFullPresentation;
	EndIf;
	
	OpenForm(Item.Value + ".ChoiceForm", FormParameters, FormOwner);
	
EndProcedure

&AtClient
Function QuestionTextAboutUnsavedData(WithoutChecksUsers = False)
	
	AllUsersSelected            = True;
	AllObjectsSelected                 = True;
	AllProhibitionDatesByObjectsFilled = True;
	AllProhibitionDatesBySectionsFilled = True;
	
	If Not WithoutChecksUsers
	   AND ProhibitionDatesUsers.FindRows(New Structure("Presentation", "")).Count() > 0 Then
		
		AllUsersSelected = False;
	Else
		If Not WithoutSectionsAndObjects Then
			If ShowCurrentUserSections Then
				For Each SectionDescription IN ProhibitionDates.GetItems() Do
					For Each ObjectDescription IN SectionDescription.GetItems() Do
						If ValueIsFilled(ObjectDescription.Presentation)Then
							If Not ProhibitionDateIsSet(ObjectDescription, CurrentUser) Then
								AllProhibitionDatesByObjectsFilled = False;
							EndIf;
						Else
							AllObjectsSelected = False;
							Break;
						EndIf;
					EndDo;
					If Not PurposeForAll(CurrentUser) Then
						If SectionDescription.GetItems().Count() = 0 
						   AND Not ProhibitionDateIsSet(SectionDescription, CurrentUser) Then
							AllProhibitionDatesBySectionsFilled = False;
						EndIf;
					EndIf;
				EndDo;
			Else
				For Each ObjectDescription IN ProhibitionDates.GetItems() Do
					If ValueIsFilled(ObjectDescription.Presentation) Then
						If Not PurposeForAll(CurrentUser)
						   AND Not ProhibitionDateIsSet(ObjectDescription, CurrentUser) Then
							
							AllProhibitionDatesByObjectsFilled = False;
						EndIf;
					Else
						AllObjectsSelected = False;
					EndIf;
				EndDo;
				If Not WithoutChecksUsers
				   AND AllProhibitionDatesBySectionsFilled
				   AND AllProhibitionDatesByObjectsFilled
				   AND AllObjectsSelected Then
					
					FoundStrings = ProhibitionDatesUsers.FindRows(
						New Structure("WithoutProhibitionDate", True));
					
					For Each String IN FoundStrings Do
						
						If PurposeForAll(String.User)
						   AND ValueIsFilled(String.Presentation) Then
							
							Continue;
						EndIf;
						
						AllProhibitionDatesFilled = False;
						Break;
					EndDo;
					
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	// User warning.
	QuestionText = "";
	If Not AllUsersSelected Then
		QuestionText = QuestionText +
			MessageTextSettingsWithUnselectedUsersNotSaved(ThisObject);
		
	ElsIf Not AllObjectsSelected Then
		QuestionText = QuestionText + Chars.LF +
			MessageTextSettingsWithUnselectedObjectsNotSaved();
		
	ElsIf Not AllProhibitionDatesBySectionsFilled Then
		QuestionText = QuestionText + Chars.LF +
			MessageTextSettingsWithUnfilledProhibitionDatesForSectionsNotSaved();
		
	ElsIf Not AllProhibitionDatesByObjectsFilled Then
		QuestionText = QuestionText + Chars.LF +
			MessageTextSettingsWithUnfilledProhibitionDatesForObjectsNotSaved();
	EndIf;
	
	Return TrimL(QuestionText);
	
EndFunction

&AtClient
Function TextNotificationsOfUnusedSettingModes()
	
	If Not ValueIsFilled(CurrentUser) Then
		Return "";
	EndIf;
	
	ProhibitionDateSettingInDatabase = "";
	SpecifiedModeInDataBase = "";
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("DataImportingProhibitionDates",    Parameters.DataImportingProhibitionDates);
	AdditionalParameters.Insert("User",                 CurrentUser);
	AdditionalParameters.Insert("SingleSection",           SingleSection);
	AdditionalParameters.Insert("FirstSection",                 FirstSection);
	AdditionalParameters.Insert("ValueForAllUsers", ValueForAllUsers);
	
	GetCurrentSettings(
		ProhibitionDateSettingInDatabase, SpecifiedModeInDataBase, AdditionalParameters);
	
	// User notification
	TextNotifications = "";
	If ProhibitionDateSetting <> ProhibitionDateSettingInDatabase Then
		
		ItemOfList = Items.ProhibitionDateSetting.ChoiceList.FindByValue(
			ProhibitionDateSetting);
		
		If ItemOfList = Undefined Then
			ProhibitionDateSettingPresentation = ProhibitionDateSetting;
		Else
			ProhibitionDateSettingPresentation = ItemOfList.Presentation;
		EndIf;
		
		ItemOfList = Items.ProhibitionDateSetting.ChoiceList.FindByValue(
			ProhibitionDateSettingInDatabase);
		
		If ItemOfList = Undefined Then
			ProhibitionDateSettingInDataBasePresentation = ProhibitionDateSettingInDatabase;
		Else
			ProhibitionDateSettingInDataBasePresentation = ItemOfList.Presentation;
		EndIf;
		
		TextNotifications = MessageTextProhibitionDateSettingNotUsed(
			ProhibitionDateSettingPresentation, ProhibitionDateSettingInDataBasePresentation);
	EndIf;
	
	If PurposeForAll(CurrentUser)
	   AND SpecifiedModeInDataBase = "" Then
		
		SpecifiedModeInDataBase = "CommonDate";
	EndIf;
	
	If ProhibitionDateSpecifiedMode <> SpecifiedModeInDataBase
	   AND ProhibitionDateSettingInDatabase <> "NoProhibition"
	   AND (ProhibitionDateSetting = ProhibitionDateSettingInDatabase
	      OR PurposeForAll(CurrentUser) ) Then
		
		If ValueIsFilled(TextNotifications) Then
			TextNotifications = TextNotifications + Chars.LF + Chars.LF;
		EndIf;
		
		ItemOfList = Items.ProhibitionDateSpecifiedMode.ChoiceList.FindByValue(
			ProhibitionDateSpecifiedMode);
		
		If ItemOfList = Undefined Then
			SpecificationMethodPresentation = ProhibitionDateSpecifiedMode;
		Else
			SpecificationMethodPresentation = ItemOfList.Presentation;
		EndIf;
		
		ItemOfList = Items.ProhibitionDateSpecifiedMode.ChoiceList.FindByValue(
			SpecifiedModeInDataBase);
		
		If ItemOfList = Undefined Then
			SpecifiedModeInDataBasePresentation = SpecifiedModeInDataBase;
		Else
			SpecifiedModeInDataBasePresentation = ItemOfList.Presentation;
		EndIf;
		
		TextNotifications = TextNotifications + MessageTextSpecifiedModeNotUsed(
			SpecificationMethodPresentation,
			SpecifiedModeInDataBasePresentation,
			CurrentUser,
			ThisObject);
	EndIf;
	
	Return TextNotifications;
	
EndFunction

&AtServerNoContext
Procedure GetCurrentSettings(ProhibitionDateSetting, SpecificationMethod, Val Parameters)
	
	ProhibitionDateSetting = ProhibitionDateCurrentSetting(Parameters.DataImportingProhibitionDates);
	If ProhibitionDateSetting = "NoProhibition" Then
		Return;
	EndIf;
	
	SpecificationMethod = ProhibitionDateCurrentSpecifiedMode(
		Parameters.User,
		Parameters.SingleSection,
		Parameters.FirstSection,
		Parameters.ValueForAllUsers);
	
EndProcedure

&AtServerNoContext
Function ProhibitionDateCurrentSetting(DataImportingProhibitionDates)
	
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("DataImportingProhibitionDates", DataImportingProhibitionDates);
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS AreProhibitions
		|FROM
		|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|WHERE
		|	(ChangeProhibitionDates.User = UNDEFINED
		|			OR CASE
		|				WHEN VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.Users)
		|						OR VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.UsersGroups)
		|						OR VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.ExternalUsers)
		|						OR VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.ExternalUsersGroups)
		|						OR ChangeProhibitionDates.User = VALUE(Enum.ProhibitionDatesPurposeKinds.ForAllUsers)
		|					THEN &DataImportingProhibitionDates = FALSE
		|				ELSE &DataImportingProhibitionDates = TRUE
		|			END)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TRUE AS ByUsers
		|FROM
		|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|WHERE
		|	(ChangeProhibitionDates.User = UNDEFINED
		|			OR CASE
		|				WHEN VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.Users)
		|						OR VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.UsersGroups)
		|						OR VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.ExternalUsers)
		|						OR VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.ExternalUsersGroups)
		|					THEN &DataImportingProhibitionDates = FALSE
		|				ELSE &DataImportingProhibitionDates = TRUE
		|			END)
		|	AND VALUETYPE(ChangeProhibitionDates.User) <> Type(Enum.ProhibitionDatesPurposeKinds)";
		
		ResultsOfQuery = Query.ExecuteBatch();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If ResultsOfQuery[0].IsEmpty() Then
		ProhibitionDatesCurrentSetting = "NoProhibition";
		
	ElsIf ResultsOfQuery[1].IsEmpty() Then
		ProhibitionDatesCurrentSetting = "ForAllUsers";
	Else
		ProhibitionDatesCurrentSetting = "ByUsers";
	EndIf;
	
	Return ProhibitionDatesCurrentSetting;
	
EndFunction

&AtServer
Procedure SetVisible()
	
	ChangeVisible(Items.SettingsOfProhibitionDate, ProhibitionDateSetting <> "NoProhibition");
	
	If ProhibitionDateSetting = "NoProhibition" Then
		Return;
	EndIf;
	
	If ProhibitionDateSetting <> "ForAllUsers" Then
		ChangeVisible(Items.SettingByUsers, True);
		Items.CurrentUserPresentation.ShowTitle = True;
	Else
		ChangeVisible(Items.SettingByUsers, False);
		Items.CurrentUserPresentation.ShowTitle = False;
	EndIf;
	
	If ProhibitionDateSetting <> "ByUsers" Then
		Items.UserData.CurrentPage = Items.PageSelectedUser;
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeVisible(Item, Visible)
	
	If Item.Visible <> Visible Then
		Item.Visible = Visible;
	EndIf;
	
EndProcedure

&AtServer
Function ChangeProhibitionDateSetting(Val ValueSelected, Val DeleteUnneeded)
	
	If DeleteUnneeded Then
		
		BeginTransaction();
		Try
			Query = New Query;
			Query.SetParameter("DataImportingProhibitionDates",
				Parameters.DataImportingProhibitionDates);
			
			If ValueSelected = "NoProhibition" Then
				Query.SetParameter("LeaveForAllUsers", False);
				
			ElsIf ValueSelected = "ForAllUsers" Then
				Query.SetParameter("LeaveForAllUsers", True);
			Else
				Query.SetParameter("DataImportingProhibitionDates", Undefined);
			EndIf;
			
			Query.Text =
			"SELECT
			|	ChangeProhibitionDates.Section,
			|	ChangeProhibitionDates.Object,
			|	ChangeProhibitionDates.User
			|FROM
			|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
			|WHERE
			|	(ChangeProhibitionDates.User = UNDEFINED
			|			OR CASE
			|				WHEN VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.Users)
			|						OR VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.UsersGroups)
			|						OR VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.ExternalUsers)
			|						OR VALUETYPE(ChangeProhibitionDates.User) = Type(Catalog.ExternalUsersGroups)
			|						OR ChangeProhibitionDates.User = VALUE(Enum.ProhibitionDatesPurposeKinds.ForAllUsers)
			|					THEN &DataImportingProhibitionDates = FALSE
			|				ELSE &DataImportingProhibitionDates = TRUE
			|			END)
			|	AND CASE
			|			WHEN VALUETYPE(ChangeProhibitionDates.User) = Type(Enum.ProhibitionDatesPurposeKinds)
			|				THEN &LeaveForAllUsers = FALSE
			|			ELSE TRUE
			|		END";
			ValuesKeysRecords = Query.Execute().Unload();
			
			// Deleted records lock.
			For Each KeyValuesRecords IN ValuesKeysRecords Do
				LockUserRecord(
					ThisObject,
					KeyValuesRecords.Section,
					KeyValuesRecords.Object,
					KeyValuesRecords.User);
			EndDo;
			
			// Delete locked records.
			For Each KeyValuesRecords IN ValuesKeysRecords Do
				DeleteUserRecord(
					KeyValuesRecords.Section,
					KeyValuesRecords.Object,
					KeyValuesRecords.User);
			EndDo;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			UnlockAllRecords(ThisObject);
			Raise;
		EndTry;
		UnlockAllRecords(ThisObject);
	EndIf;
	
	ReadUsers();
	ReadUserData(ThisObject);
	
	SetVisible();
	
EndFunction

&AtServerNoContext
Function ProhibitionDateCurrentSpecifiedMode(Val User, Val SingleSection, Val FirstSection, Val ValueForAllUsers, Data = Undefined)
	
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("User",                 User);
		Query.SetParameter("FirstSection",                 FirstSection);
		Query.SetParameter("BlankDate",                   '00000000');
		Query.SetParameter("ValueForAllUsers", ValueForAllUsers);
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|WHERE
		|	Not(&User <> ChangeProhibitionDates.User
		|				AND &User <> ""*"")
		|	AND Not(ChangeProhibitionDates.Section = VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef)
		|				AND ChangeProhibitionDates.Object = VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|WHERE
		|	Not(&User <> ChangeProhibitionDates.User
		|				AND &User <> ""*"")
		|	AND ChangeProhibitionDates.Section <> VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef)
		|	AND ChangeProhibitionDates.Object <> VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef)
		|	AND ChangeProhibitionDates.Object <> ChangeProhibitionDates.Section
		|	AND ChangeProhibitionDates.Object <> UNDEFINED
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|WHERE
		|	Not(&User <> ChangeProhibitionDates.User
		|				AND &User <> ""*"")
		|	AND ChangeProhibitionDates.Section <> VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef)
		|	AND ChangeProhibitionDates.Section <> &FirstSection
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	TRUE
		|FROM
		|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|WHERE
		|	Not(&User <> ChangeProhibitionDates.User
		|				AND &User <> ""*"")
		|	AND ChangeProhibitionDates.Section <> VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef)
		|	AND ChangeProhibitionDates.Section = ChangeProhibitionDates.Object";
		
		ResultsOfQuery = Query.ExecuteBatch();
		
		ProhibitionDateCurrentSpecifiedMode = "";
		
		Query.Text =
		"SELECT
		|	ChangeProhibitionDates.ProhibitionDate,
		|	ChangeProhibitionDates.ProhibitionDateDescription
		|FROM
		|	InformationRegister.ChangeProhibitionDates AS ChangeProhibitionDates
		|WHERE
		|	ChangeProhibitionDates.User = &User
		|	AND ChangeProhibitionDates.Section = VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef)
		|	AND ChangeProhibitionDates.Object = VALUE(ChartOfCharacteristicTypes.ChangingProhibitionDatesSections.EmptyRef)";
		Selection = Query.Execute().Select();
		CommonDateRead = Selection.Next();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Data = Undefined Then
		Data = New Structure;
		Data.Insert("ProhibitionDateDescription", "Custom");
		Data.Insert("ProhibitionDate", '00000000');
		Data.Insert("PermissionDaysCount", 0);
	EndIf;
	
	If CommonDateRead Then
		Data.ProhibitionDate = Selection.ProhibitionDate;
		FillByInnerDescriptionProhibitionDates(Data, Selection.ProhibitionDateDescription);
	EndIf;
	
	If ResultsOfQuery[0].IsEmpty() Then
		// It is not by objects and by sections when it is empty.
		ProhibitionDateCurrentSpecifiedMode = ?(CommonDateRead, "CommonDate", "");
		
	ElsIf Not ResultsOfQuery[1].IsEmpty() Then
		// It is by objects when it is not empty.
		
		If ResultsOfQuery[2].IsEmpty()
		   AND SingleSection Then
			// Only by FirstSection (without dates by sections) when it is empty.
			ProhibitionDateCurrentSpecifiedMode = "ByObjects";
		Else
			ProhibitionDateCurrentSpecifiedMode = "BySectionsAndObjects";
		EndIf;
	Else
		ProhibitionDateCurrentSpecifiedMode = "BySections";
	EndIf;
	
	Return ProhibitionDateCurrentSpecifiedMode;
	
EndFunction

&AtServer
Function DeleteUnneededOnChangeProhibitionDateSpecifiedMode(Val ValueSelected, Val CurrentUser, Val ProhibitionDateSetting)
	
	RecordSet = InformationRegisters.ChangeProhibitionDates.CreateRecordSet();
	RecordSet.Filter.User.Set(CurrentUser);
	RecordSet.Read();
	IndexOf = RecordSet.Count()-1;
	While IndexOf >= 0 Do
		Record = RecordSet[IndexOf];
		If  ValueSelected = "CommonDate" Then
			If Not (  Record.Section = SectionEmptyRef
					 AND Record.Object = SectionEmptyRef ) Then
				RecordSet.Delete(Record);
			EndIf;
		ElsIf ValueSelected = "BySections" Then
			If Record.Section <> Record.Object
			 OR Record.Section = SectionEmptyRef
			   AND Record.Object = SectionEmptyRef Then
				RecordSet.Delete(Record);
			EndIf;
		ElsIf ValueSelected = "ByObjects" Then
			If Record.Section = Record.Object
			   AND Record.Section <> SectionEmptyRef
			   AND Record.Object <> SectionEmptyRef Then
				RecordSet.Delete(Record);
			EndIf;
		EndIf;
		IndexOf = IndexOf-1;
	EndDo;
	RecordSet.Write();
	
	ReadUserData(ThisObject);
	
EndFunction

&AtClient
Procedure ChooseSections()
	
	DataCollection = ProhibitionDates.GetItems();
	
	SectionNotFound = True;
	SectionsForMark = New ValueList;
	For Each CollectionItem IN DataCollection Do
		If CollectionItem.Section = SectionEmptyRef Then
			SectionNotFound = False;
		EndIf;
	EndDo;
	If SectionNotFound Then
		SectionsForMark.Add(SectionEmptyRef, PresentationCommonDateText());
	EndIf;
	
	If ProhibitionDateSpecifiedMode <> "ByObjects" Then
		For Each String IN SectionObjectsTypes Do
			SectionNotFound = True;
			For Each CollectionItem IN DataCollection Do
				If CollectionItem.Section = String.Section Then
					SectionNotFound = False;
				EndIf;
			EndDo;
			If SectionNotFound Then
				SectionsForMark.Add(String.Section);
			EndIf;
		EndDo;
	EndIf;
	
	If SectionsForMark.Count() = 0 Then
		If ProhibitionDateSpecifiedMode = "ByObjects" Then
			ShowMessageBox(, MessageTextCommonDateAlreadyShown());
		Else
			ShowMessageBox(, MessageTextAllSectionsAlreadyShown());
		EndIf;
	Else
		SectionsForMark.ShowCheckItems(
			New NotifyDescription("SelectSectionsEnd", ThisObject, SectionsForMark),
			TitleChoiceOfRequiredSections());
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectSectionsEnd(Result, SectionsForMark) Export
	
	If Result = False Then
		Return;
	EndIf;
	
	AddSections(SectionsForMark, Items.Users.CurrentData.Comment);
	NotifyChanged(Type("InformationRegisterRecordKey.ChangeProhibitionDates"));
	
EndProcedure

&AtServer
Procedure AddSections(MarkedSections, Comment)
	
	ProhibitionDatesTree = FormAttributeToValue("ProhibitionDates");
	
	For Each SectionDescription IN MarkedSections Do
		If SectionDescription.Check Then
			LockAndRecordEmptyDates(
				SectionDescription.Value,
				SectionDescription.Value,
				CurrentUser, Comment);
			
			DataItem = ProhibitionDatesTree.Rows.Add();
			DataItem.ThisIsSection = True;
			DataItem.Section = SectionDescription.Value;
			DataItem.Object = SectionDescription.Value;
			If SectionDescription.Value = SectionEmptyRef Then
				DataItem.Presentation = PresentationCommonDateText();
			Else
				DataItem.Presentation = String(SectionDescription.Value);
			EndIf;
			DataItem.FullPresentation = DataItem.Presentation;
			DataItem.ProhibitionDateDescription = "Custom";
			
			DataItem.ProhibitionDateDescriptionPresentation =
				PresentationOfProhibitionDateDescription(DataItem);
		EndIf;
	EndDo;
	
	ProhibitionDatesTree.Rows.Sort("FullPresentation Asc");
	
	ValueToFormAttribute(ProhibitionDatesTree, "ProhibitionDates");
	
EndProcedure

&AtClient
Procedure EditProhibitionDateInForm()
	
	SelectedRows = Items.ProhibitionDates.SelectedRows;
	// Cancel highlighting strings of sections with objects.
	IndexOf = SelectedRows.Count()-1;
	RefreshSelection = False;
	While IndexOf >= 0 Do
		String = ProhibitionDates.FindByID(SelectedRows[IndexOf]);
		If Not ValueIsFilled(String.Presentation) Then
			SelectedRows.Delete(IndexOf);
			RefreshSelection = True;
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	If SelectedRows.Count() = 0 Then
		ShowMessageBox(, MessageTextSelectedStringsNotFilledIn());
		Return;
	EndIf;
	
	If RefreshSelection Then
		Items.ProhibitionDates.Refresh();
		ShowMessageBox(
			New NotifyDescription("EditProhibitionDateInFormEnd", ThisObject, SelectedRows),
			MessageTextUnfilledRowsAreUnmarked());
	Else
		EditProhibitionDateInFormEnd(SelectedRows)
	EndIf;
	
EndProcedure

&AtClient
Procedure EditProhibitionDateInFormEnd(SelectedRows) Export
	
	// Lock records of the highlighted strings.
	For Each SelectedRow IN SelectedRows Do
		CurrentData = ProhibitionDates.FindByID(SelectedRow);
		
		ReadProperties = LockUserRecord(
			ThisObject, CurrentSection(CurrentData), CurrentData.Object, CurrentUser);
		
		UpdateReadPropertiesValues(
			CurrentData, ReadProperties, Items.Users.CurrentData);
	EndDo;
	
	// Change the prohibition date description.
	FormParameters = New Structure;
	If ProhibitionDateSetting = "ByUsers" Then
		FormParameters.Insert("UserPresentation",
			Items.Users.CurrentData.Presentation);
	Else
		FormParameters.Insert("UserPresentation",
			PresentationTextForAllUsers(ThisObject));
	EndIf;
	
	If SelectedRows.Count() = 1 Then
		If ProhibitionDateSpecifiedMode = "ByObjects" Then
			
			If Items.ProhibitionDates.CurrentData.ThisIsSection Then
				FormParameters.Insert("SectionPresentation",
					Items.ProhibitionDates.CurrentData.Presentation);
				FormParameters.Insert("ObjectPresentation", "");
			Else
				FormParameters.Insert("SectionPresentation", "");
				FormParameters.Insert("ObjectPresentation",
					Items.ProhibitionDates.CurrentData.Presentation);
			EndIf;
		Else
			If Items.ProhibitionDates.CurrentData.ThisIsSection Then
				FormParameters.Insert("SectionPresentation",
					Items.ProhibitionDates.CurrentData.Presentation);
				
				SectionWithoutObjects = SectionsWithoutObjects.FindByValue(
					Items.ProhibitionDates.CurrentData.Section) <> Undefined;
				
				If Not SectionWithoutObjects
				   AND PurposeForAll(CurrentUser) Then
					
					FormParameters.Insert("AllowByDefault", True);
				EndIf;
			Else
				FormParameters.Insert("SectionPresentation",
					Items.ProhibitionDates.CurrentData.GetParent().Presentation);
				
				FormParameters.Insert("ObjectPresentation",
					Items.ProhibitionDates.CurrentData.Presentation);
			EndIf;
		EndIf;
	Else
		FormParameters.Insert("SectionPresentation", "<...>");
		FormParameters.Insert("ObjectPresentation", "<...>");
	EndIf;
	FormParameters.Insert("ProhibitionDateDescription",
		Items.ProhibitionDates.CurrentData.ProhibitionDateDescription);
	
	FormParameters.Insert("PermissionDaysCount",
		Items.ProhibitionDates.CurrentData.PermissionDaysCount);
	
	FormParameters.Insert("ProhibitionDate",
		Items.ProhibitionDates.CurrentData.ProhibitionDate);
	
	OpenForm("InformationRegister.ChangeProhibitionDates.Form.ProhibitionDateEditing",
		FormParameters, ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Function PresentationOfProhibitionDateDescription(Val Data)
	
	Presentation = DescriptionsProhibitionDateList().FindByValue(
		Data.ProhibitionDateDescription).Presentation;
	
	If Data.PermissionDaysCount > 0 Then
		Presentation = Presentation + " (" + Format(Data.PermissionDaysCount, "NG=") + ")";
	EndIf;
	
	Return Presentation;
	
EndFunction

&AtClientAtServerNoContext
Function InnerDescriptionProhibitionDates(Val Data)
	
	InnerDetails = "";
	If Data.ProhibitionDateDescription <> "Custom" Then
		InnerDetails = TrimAll(
			Data.ProhibitionDateDescription + Chars.LF +
				Format(Data.PermissionDaysCount, "NG=0"));
	EndIf;
	
	Return InnerDetails;
	
EndFunction

&AtClientAtServerNoContext
Procedure FillByInnerDescriptionProhibitionDates(Val Data, Val InnerDetails)
	
	Data.ProhibitionDateDescription = "Custom";
	Data.PermissionDaysCount = 0;
	
	If ValueIsFilled(InnerDetails) Then
		Row1 = StrGetLine(InnerDetails, 1);
		Row2 = StrGetLine(InnerDetails, 2);
		FoundItem = DescriptionsProhibitionDateList().FindByValue(Row1);
		If FoundItem <> Undefined Then
			Data.ProhibitionDateDescription = FoundItem.Value;
			If ValueIsFilled(Row2) Then
				Try
					Data.PermissionDaysCount = Number(Row2);
				Except
				EndTry;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function PurposeForAll(User)
	
	Return TypeOf(User) = Type("EnumRef.ProhibitionDatesPurposeKinds");
	
EndFunction

&AtClientAtServerNoContext
Function ProhibitionDateIsSet(Data, User)
	
	If PurposeForAll(User) Then
		ProhibitionDateIsSet =
				ValueIsFilled(Data.ProhibitionDate)
			OR Data.ProhibitionDateDescription <> "Custom";
	Else
		ProhibitionDateIsSet =
				ValueIsFilled(Data.ProhibitionDate)
			OR Data.ProhibitionDateDescription <> "";
	EndIf;
	
	Return ProhibitionDateIsSet;
	
EndFunction

&AtServer
Procedure LockAndRecordEmptyDates(Section, Object, User, Comment)
	
	If TypeOf(Object) = Type("Array") Then
		ObjectsToAdd = Object;
	Else
		ObjectsToAdd = New Array;
		ObjectsToAdd.Add(Object);
	EndIf;
	
	For Each CurrentObject IN ObjectsToAdd Do
		LockUserRecord(ThisObject, Section, CurrentObject, User);
	EndDo;
	
	For Each CurrentObject IN ObjectsToAdd Do
		WriteProhibitionDateWithDescription(
			Section,
			CurrentObject,
			User,
			'00000000',
			"",
			Comment);
	EndDo;
	
	UnlockAllRecords(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetProhibitionDatesCommandBar(Context)
	
	Items = Context.Items;
	
	If PurposeForAll(Context.CurrentUser) Then
		If Context.ProhibitionDateSpecifiedMode = "BySections" Then
			// ProhibitionDatesWithoutSectionsChoiceWithoutObjectsChoice
			SetProperty(Items.ProhibitionDataSections.Visible,   False);
			SetProperty(Items.ProhibitionDatesPick.Visible, False);
			SetProperty(Items.ProhibitionDatesAdd.Visible,  False);
			SetProperty(Items.ProhibitionDatesContextMenuAdd.Visible, False);
			SetProperty(Items.ProhibitionDatesChange.Representation, ButtonRepresentation.Text);
			SetProperty(Items.ProhibitionDatesChange.OnlyInAllActions, False);
		Else
			// ProhibitionDatesWithoutSectionsChoiceWithObjectsChoice
			SetProperty(Items.ProhibitionDataSections.Visible,   False);
			SetProperty(Items.ProhibitionDatesPick.Visible, True);
			SetProperty(Items.ProhibitionDatesAdd.Visible,  True);
			SetProperty(Items.ProhibitionDatesContextMenuAdd.Visible, True);
			SetProperty(Items.ProhibitionDatesChange.Representation, ButtonRepresentation.Auto);
			SetProperty(Items.ProhibitionDatesChange.OnlyInAllActions, Not Context.InterfaceVersion82);
		EndIf;
	Else
		If Context.ProhibitionDateSpecifiedMode = "BySections" Then
			// ProhibitionDatesWithSectionsChoiceWithoutObjectsChoice
			SetProperty(Items.ProhibitionDataSections.Visible,   True);
			SetProperty(Items.ProhibitionDataSections.Title,   NStr("en='Sections';ru='секции'"));
			SetProperty(Items.ProhibitionDatesPick.Visible, False);
			SetProperty(Items.ProhibitionDatesAdd.Visible,  False);
			SetProperty(Items.ProhibitionDatesContextMenuAdd.Visible, False);
			SetProperty(Items.ProhibitionDatesChange.Representation, ButtonRepresentation.Auto);
			SetProperty(Items.ProhibitionDatesChange.OnlyInAllActions, Not Context.InterfaceVersion82);
			
		ElsIf Context.ProhibitionDateSpecifiedMode = "ByObjects" Then
			// ProhibitionDatesWithCommonDateChoiceWithObjectsChoice
			SetProperty(Items.ProhibitionDataSections.Visible,   True);
			SetProperty(Items.ProhibitionDataSections.Title,   NStr("en='Common date';ru='Общая дата'"));
			SetProperty(Items.ProhibitionDatesPick.Visible, True);
			SetProperty(Items.ProhibitionDatesAdd.Visible,  True);
			SetProperty(Items.ProhibitionDatesContextMenuAdd.Visible, True);
			SetProperty(Items.ProhibitionDatesChange.Representation, ButtonRepresentation.Auto);
			SetProperty(Items.ProhibitionDatesChange.OnlyInAllActions, Not Context.InterfaceVersion82);
		Else
			// ProhibitionDatesWithSectionsChoiceWithObjectsChoice
			SetProperty(Items.ProhibitionDataSections.Visible,   True);
			SetProperty(Items.ProhibitionDataSections.Title,   NStr("en='Sections';ru='секции'"));
			SetProperty(Items.ProhibitionDatesPick.Visible, True);
			SetProperty(Items.ProhibitionDatesAdd.Visible,  True);
			SetProperty(Items.ProhibitionDatesContextMenuAdd.Visible, True);
			SetProperty(Items.ProhibitionDatesAdd.OnlyInAllActions, Not Context.InterfaceVersion82);
			SetProperty(Items.ProhibitionDatesChange.Representation, ButtonRepresentation.Auto);
			SetProperty(Items.ProhibitionDatesChange.OnlyInAllActions, Not Context.InterfaceVersion82);
		EndIf;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetProperty(Property, Value)
	If Property <> Value Then
		Property = Value;
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Function CurrentUserComment(Context)
	
	If Context.ProhibitionDateSetting = "ByUsers" Then
		Comment = Context.Items.Users.CurrentData.Comment;
	Else
		Comment = CommentTextForAllUsers();
	EndIf;
	
	Return Comment;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Same procedure and function of forms ChangeProhibitionDates and ProhibitionDateEditing.

&AtClientAtServerNoContext
Procedure CommonProhibitionDateWithDescriptionOnChange(Val Context, CalculateProhibitionDate = True);
	
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
				LabelText = Chars.LF +
					NStr("en='Period of changing data from %3 to %4 expired on %2';ru='Срок возможности изменения данных с %3 по %4 истек %2'");
			Else
				If CalculateProhibitionDate Then
					Context.ProhibitionDate = CalculatedProhibitionDates.Previous;
				EndIf;
				LabelText = Chars.LF +
					NStr("en='For %2 data might change from %3 to %4';ru='По %2 возможно изменение данных с %3 по %4'") + Chars.LF +
					NStr("en='After %2 it will be prohibited to change %4 data';ru='После %2 будет запрещено изменение данных по %4'") + Chars.LF;
			EndIf;
		Else
			Context.Items.PropertyPermissionDaysCountChanges.CurrentPage = Context.Items.DataChangingBeforeProhibitionDateIsNotAllowed;
			Context.PermissionDaysCount = 0;
		EndIf;
		Context.Items.AutomaticalDateExplanation.Title =
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Changing of data on %1 is prohibited';ru='Запрещено изменение данных по %1'") + LabelText,
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

////////////////////////////////////////////////////////////////////////////////
// Helper functions of the user interface strings.

&AtClientAtServerNoContext
Function DescriptionsProhibitionDateList()
	
	List = New ValueList;
	List.Add("",                "(" + NStr("en='Default';ru='По умолчанию'") + ")");
	List.Add("Custom",      NStr("en='Custom date';ru='Произвольная дата'"));
	List.Add("LastYearEnd",     NStr("en='Last year end';ru='Конец прошлого года'"));
	List.Add("LastQuarterEnd", NStr("en='Last quarter end';ru='Конец прошлого квартала'"));
	List.Add("LastMonthEnd",   NStr("en='Last month end';ru='Конец прошлого месяца'"));
	List.Add("LastWeekEnd",    NStr("en='Last week end';ru='Конец прошлой недели'"));
	List.Add("PreviousDay",        NStr("en='Previous day';ru='Предыдущий день'"));
	
	Return List;
	
EndFunction

&AtClientAtServerNoContext
Function PresentationTextForAllUsers(Context)
	
	Return "<" + Context.ValueForAllUsers + ">";
	
EndFunction

&AtClientAtServerNoContext
Function UserPresentationText(Context, User)
	
	If Context.Parameters.DataImportingProhibitionDates Then
		For Each ListValue IN Context.ListOfUserTypes Do
			If TypeOf(ListValue.Value) = TypeOf(User) Then
				If ValueIsFilled(User) Then
					Return ListValue.Presentation + ": " +
						String(User);
				Else
					Return ListValue.Presentation + ": " +
						NStr("en='<All infobases>';ru='<Все информационные базы>'");
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If ValueIsFilled(User) Then
		Return String(User);
	EndIf;
	
	Return String(TypeOf(User));
	
EndFunction

&AtClientAtServerNoContext
Function CommentTextForAllUsers()
	
	Return "(" + NStr("en='Default';ru='По умолчанию'") + ")";
	
EndFunction

&AtClientAtServerNoContext
Function PresentationCommonDateText()
	
	Return "<" + NStr("en='Common date';ru='Общая дата'") + ">";
	
EndFunction

&AtClientAtServerNoContext
Function ReportByObjectCommandHeaderText()
	
	Return NStr("en='Report by objects';ru='Отчет по объектам'");
	
EndFunction

&AtClientAtServerNoContext
Function ReportBySectionsCommandHeaderText()
	
	Return NStr("en='Report by sections';ru='Отчет по разделам'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextCloseForm()
	
	Return NStr("en='Close the form?';ru='Закрыть форму?'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextRecalculateProhibitionDates()
	
	Return NStr("en='Clear the unfilled lines and recalculate relative closing dates?';ru='Очистить незаполненные строки и пересчитать относительные даты запрета?'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextUpdateData()
	
	Return NStr("en='Update data?';ru='Обновить данные?'");
	
EndFunction

&AtClient
Function QuestionTextDeleteAllProhibitionDatesExceptDatesForAllUsers()
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Delete all closing dates except for the set ones %1?';ru='Удалить все даты запрета, кроме установленных %1?'"),
		ValueForAllUsers);
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteAllProhibitionDates()
	
	Return NStr("en='Delete all closing dates?';ru='Удалить все даты запрета?'");
	
EndFunction

&AtClient
Function MessageTextValueForAllUsersNotChange()
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Value %1 is not being changed.';ru='Значение %1 не изменяется.'"),
		PresentationTextForAllUsers(ThisObject));
	
EndFunction

&AtClient
Function MessageTextCommentForAllUsersNotChange()
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Comment %1 cannot be changed.';ru='Комментарий %1 не изменяется.'"),
		PresentationTextForAllUsers(ThisObject));
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextFirstSelectUser()
	
	Return NStr("en='Select user first.';ru='Сначала выберите пользователя.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextProhibitionDateSettingNotUsed(ProhibitionDateSettingToForm, ProhibitionDateSettingInDatabase)
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Prohibition date setting
		|""%1"" is not set, therefore, prohibition date setting will be saved ""%2"".';ru='Установка
		|даты запрета ""%1"" не настроена, поэтому будет сохранена установка даты запрета ""%2"".'"),
		ProhibitionDateSettingToForm,
		ProhibitionDateSettingInDatabase);
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextSpecifiedModeNotUsed(SpecifiedModeInForm, SpecifiedModeInDataBase, CurrentUser, Form)
	
	If PurposeForAll(CurrentUser) Then
		Return StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Prohibition date specification
		|method ""%1"" is not set
		|for ""%2"", therefore, prohibition date specification method will be saved ""%3"".';ru='Способ
		|указания даты запрета ""%1""
		|не настроен ""%2"", поэтому будет сохранен способ указания даты запрета ""%3"".'"),
			SpecifiedModeInForm,
			PresentationTextForAllUsers(Form),
			SpecifiedModeInDataBase);
	Else
		Return StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Prohibition date specification
		|method ""%1"" is not set for
		|""%1"", therefore, prohibition date specification method will be saved ""%3"".';ru='Способ
		|указания даты запрета ""%1"" не
		|настроен для ""%2"", поэтому будет сохранен способ указания даты запрета ""%3"".'"),
			SpecifiedModeInForm,
			CurrentUser,
			SpecifiedModeInDataBase);
	EndIf;
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextClearBlankRows()
	
	Return NStr("en='Clear unfilled lines?';ru='Очистить незаполненные строки?'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextForDeletingSelectOneRow()
	
	Return NStr("en='Mark one line for deletion.';ru='Для удаления выделите одну строку.'");
	
EndFunction

&AtClient
Function QuestionTextDeleteProhibitionDatesForAllUsers()
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Delete the %1 closing dates?';ru='Удалить даты запрета %1?'"), Lower(ValueForAllUsers));
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteProhibitionDatesForUser()
	
	Return NStr("en='Delete closing dates for a user?';ru='Удалить даты запрета для пользователя?'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteProhibitionDatesForUsersGroups()
	
	Return NStr("en='Delete closing dates for a user group?';ru='Удалить даты запрета для группы пользователей?'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteProhibitionDatesForExternalUser()
	
	Return NStr("en='Delete closing dates for an external user?';ru='Удалить даты запрета для внешнего пользователя?'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteProhibitionDatesForExternalUsersGroups()
	
	Return NStr("en='Delete closing dates for external users group?';ru='Удалить даты запрета для группы внешних пользователей?'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteProhibitionDates()
	
	Return NStr("en='Remove closing dates?';ru='Удалить даты запрета?'");
	
EndFunction

&AtClient
Function MessageTextForAllUsersProhibitionDatesIsNotSet()
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='%1 closing dates are not set.';ru='%1 даты запрета не установлены.'"), ValueForAllUsers);
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextValueAlreadyAddedToList()
	
	Return NStr("en='The value has already been added to the list.';ru='Значение уже добавлено в список.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextUpdateFormF5Data()
	
	Return NStr("en='Update form data (F5).';ru='Обновите данные формы (F5).'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteProhibitionDatesForSectionsAndObjects()
	
	Return NStr("en='Delete closing dates for sections and objects?';ru='Удалить даты запрета для разделов и объектов?'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteProhibitionDatesForObjects()
	
	Return NStr("en='Delete closing dates for objects?';ru='Удалить даты запрета для объектов?'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteProhibitionDatesForSections()
	
	Return NStr("en='Delete closing dates for sections?';ru='Удалить даты запрета для разделов?'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextInSelectedSectionProhibitionDatesForObjectNotSet()
	
	Return NStr("en='Closing dates for objects are not set in the selected section.';ru='В выбранном разделе даты запрета для объектов не устанавливаются.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextCommonDateCanBeSet()
	
	Return NStr("en='<Common date> can be set.';ru='<Общая дата> может быть установлена.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextSectionsAlreadyFilledCanSetProhibitionDatesForSections()
	
	Return NStr("en='Sections
		|are already filled in,
		|you can set the prohibition dates for sections.';ru='Разделы
		|уже заполнены,
		|можно установить даты запрета для разделов.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextSectionsAlreadyFilledCanSetProhibitionDatesForSectionsAndObjects()
	
	Return NStr("en='Sections
		|are already filled in,
		|you can set the prohibition date for sections and objects.';ru='Разделы
		|уже заполнены,
		|можно установить даты запрета для разделов и объектов.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextObjectAlreadySelectedCanSetProhibitionDate()
	
	Return NStr("en='Object
		|is already selected, you can set the prohibition date.';ru='Объект
		|уже выбран, можно установить дату запрета.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextFirstSelectObject()
	
	Return NStr("en='Select object first.';ru='Сначала выберите объект.'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteProhibitionDatesForSectionAndObjects()
	
	Return NStr("en='Delete closing dates for sections and objects?';ru='Удалить даты запрета для разделов и объектов?'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteProhibitionDatesForSection()
	
	Return NStr("en='Delete a closing date for a section?';ru='Удалить дату запрета для раздела?'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteCommonProhibitionDate()
	
	Return NStr("en='Delete common closing date?';ru='Удалить общую дату запрета?'");
	
EndFunction

&AtClientAtServerNoContext
Function QuestionTextDeleteObjectProhibitionDate()
	
	Return NStr("en='Delete a closing date for an object?';ru='Удалить дату запрета для объекта?'");
	
EndFunction

&AtClient
Function MessageTextForAllUsersSectionsAlwaysShow()
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='%1 sections are always shown.';ru='%1 разделы всегда показываются.'"), ValueForAllUsers);
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextWhenDeletingProhibitionDateCleared()
	
	Return NStr("en='On deletion, closing date is cleared.';ru='При удалении дата запрета очищается.'");
	
EndFunction

&AtClient
Function MessageTextForAllUsersCommonDateAlwaysShow()
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='%1 <Common date> is always shown.';ru='%1 <Общая дата> всегда показывается.'"), ValueForAllUsers);
	
EndFunction

&AtClientAtServerNoContext
Function SectionTitleText()
	
	Return NStr("en='Section';ru='Раздел'");
	
EndFunction

&AtClientAtServerNoContext
Function SectionWithObjectsTitleText()
	
	Return NStr("en='Section, object';ru='Раздел, объект'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextNotEnoughRightsForChoiceOfExternalUsers()
	
	Return NStr("en='Insufficient rights to select external users.';ru='Недостаточно прав для выбора внешних пользователей.'");
	
EndFunction

&AtClientAtServerNoContext
Function TitleTextChoiceDataType()
	
	Return NStr("en='Select data type';ru='Выбор типа данных'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextSettingsWithUnselectedUsersNotSaved(Context)
	
	If Context.Parameters.DataImportingProhibitionDates Then
		Return NStr("en='Settings with unselected infobases are not saved.';ru='Настройки с невыбранными информационными базами не сохранены.'");
	EndIf;
	
	Return NStr("en='Settings with unselected users are not saved.';ru='Настройки с невыбранными пользователями не сохранены.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextSettingsWithUnselectedObjectsNotSaved()
	
	Return NStr("en='Settings with unselected objects are not saved.';ru='Настройки с невыбранными объектами не сохранены.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextSettingsWithUnfilledProhibitionDatesForObjectsNotSaved()
	
	Return NStr("en='Settings with unfilled closing dates for objects are not saved.';ru='Настройки с незаполненными датами запрета для объектов не сохранены.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextSettingsWithUnfilledProhibitionDatesForSectionsNotSaved()
	
	Return NStr("en='Settings with unfilled closing dates for sections are not saved.';ru='Настройки с незаполненными датами запрета для разделов не сохранены.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextCommonDateAlreadyShown()
	
	Return NStr("en='<Common date> is already shown.';ru='<Общая дата> уже показана.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextAllSectionsAlreadyShown()
	
	Return NStr("en='All sections are already shown.';ru='Все разделы уже показаны.'");
	
EndFunction

&AtClientAtServerNoContext
Function TitleChoiceOfRequiredSections()
	
	Return NStr("en='Select required sections';ru='Выбор требуемых разделов'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextUnfilledRowsAreUnmarked()
	
	Return NStr("en='Unfilled rows are unchecked.';ru='Снято выделение с незаполненных строк.'");
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextSelectedStringsNotFilledIn()
	
	Return NStr("en='The selected lines are not filled in.';ru='Выделенные строки не заполнены.'");
	
EndFunction

#EndRegion
