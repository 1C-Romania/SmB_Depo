
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess(, CommonUseReUse.ApplicationRunningMode().Local) Then
		Raise NStr("en='Insufficient rights to open infobase user list.';ru='Недостаточно прав для открытия списка пользователей информационной базы.'");
	EndIf;
	
	Users.FindAmbiguousInfobaseUsers(,);
	
	UserTypes.Add(Type("CatalogRef.Users"));
	If GetFunctionalOption("UseExternalUsers") Then
		UserTypes.Add(Type("CatalogRef.ExternalUsers"));
	EndIf;
	
	ShowOnlyProcessedInDesignerItems = True;
	
	FillInfobaseUsers();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "InfobaseUserAdded"
	 OR EventName = "InfobaseUserChanged"
	 OR EventName = "InfobaseUserDeleted"
	 OR EventName = "MatchToNonExistentIBUserCleared" Then
		
		FillInfobaseUsers();
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ShowOnlyProcessedInDesignerItemsOnChange(Item)
	
	FillInfobaseUsers();
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersIBUsers

&AtClient
Procedure IBUsersOnActivateRow(Item)
	
	CurrentData = Items.IBUsers.CurrentData;
	
	If CurrentData = Undefined Then
		CanDelete     = False;
		YouCanMap = False;
		YouCanGoToUser  = False;
		YouCanCancelCompliance = False;
	Else
		CanDelete     = Not ValueIsFilled(CurrentData.Ref);
		YouCanMap = Not ValueIsFilled(CurrentData.Ref);
		YouCanGoToUser  = ValueIsFilled(CurrentData.Ref);
		YouCanCancelCompliance = ValueIsFilled(CurrentData.Ref);
	EndIf;
	
	Items.IBUsersDelete.Enabled = CanDelete;
	
	Items.IBUsersGoToUser.Enabled                = YouCanGoToUser;
	Items.IBUsersContextMenuGoToUser.Enabled = YouCanGoToUser;
	
	Items.IBUsersMap.Enabled       = YouCanMap;
	Items.IBUsersMapWithNew.Enabled = YouCanMap;
	
	Items.IBUsersCancelMapping.Enabled = YouCanCancelCompliance;
	
EndProcedure

&AtClient
Procedure IBUsersBeforeDelete(Item, Cancel)
	
	Cancel = True;
	
	If Not ValueIsFilled(Items.IBUsers.CurrentData.Ref) Then
		DeleteCurrentIBUser(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Refresh(Command)
	
	FillInfobaseUsers();
	
EndProcedure

&AtClient
Procedure Map(Command)
	
	MapIBUser();
	
EndProcedure

&AtClient
Procedure MapWithNewItem(Command)
	
	MapIBUser(True);
	
EndProcedure

&AtClient
Procedure GoToUser(Command)
	
	OpenUserByRef();
	
EndProcedure

&AtClient
Procedure CancelMapping(Command)
	
	If Items.IBUsers.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add("CancelMapping", NStr("en='Clear mapping';ru='Отменить сопоставление'"));
	Buttons.Add("LeaveCompliance", NStr("en='Leave mapping';ru='Оставить сопоставление'"));
	
	ShowQueryBox(
		New NotifyDescription("CancelComplianceContinuation", ThisObject),
		NStr("en='Cancel mapping of infobase user with the user in catalog.
		|
		|Cancellation of mapping is required very rarely, only if the mapping
		|was completed incorrectly, for example, when updating an infobase, thus it is not recommended to cancel mapping for any other reason.';ru='Отмена сопоставления пользователя информационной базы с пользователем в справочнике.
		|
		|Отмена сопоставления требуется крайне редко - только если сопоставление было выполнено некорректно, например,
		|при обновлении информационной базы, поэтому не рекомендуется отменять сопоставление по любой другой причине.'"),
		Buttons,
		,
		"LeaveCompliance");
		
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FullName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Name.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.StandardAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSUser.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OpenIDAuthentication.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("IBUsers.AddedInDesigner");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.SpecialTextColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FullName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Name.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.StandardAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSUser.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OpenIDAuthentication.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("IBUsers.ModifiedInDesigner");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	FilterElement = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("IBUsers.DeletedInDesigner");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Name.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.StandardAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OpenIDAuthentication.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("IBUsers.DeletedInDesigner");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("Text", NStr("en='<No data>';ru='<Нет данных>'"));
	Item.Appearance.SetParameterValue("Format", "L=En; BF=No; BT=Yes");

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSAuthentication.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("IBUsers.OSUser");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Format", "L=En; BF=; BT=Yes");

EndProcedure

&AtServer
Procedure FillInfobaseUsers()
	
	EmptyUUID = New UUID("00000000-0000-0000-0000-000000000000");
	
	If Items.IBUsers.CurrentRow <> Undefined Then
		String = IBUsers.FindByID(Items.IBUsers.CurrentRow);
	Else
		String = Undefined;
	EndIf;
	
	CurrentInfobaseUserID =
		?(String = Undefined, EmptyUUID, String.InfobaseUserID);
	
	IBUsers.Clear();
	NonExistentInfobaseUserIDs.Clear();
	NonExistentInfobaseUserIDs.Add(EmptyUUID);
	
	Query = New Query;
	Query.SetParameter("EmptyUUID", EmptyUUID);
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.Description AS FullName,
	|	Users.InfobaseUserID,
	|	FALSE AS IsExternalUser
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.InfobaseUserID <> &EmptyUUID
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref,
	|	ExternalUsers.Description,
	|	ExternalUsers.InfobaseUserID,
	|	TRUE
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.InfobaseUserID <> &EmptyUUID";
	
	Exporting = Query.Execute().Unload();
	Exporting.Indexes.Add("InfobaseUserID");
	Exporting.Columns.Add("Mapped", New TypeDescription("Boolean"));
	
	AllIBUsers = InfobaseUsers.GetUsers();
	
	For Each IBUser IN AllIBUsers Do
		PropertiesIBUser = Users.NewInfobaseUserInfo();
		Users.ReadIBUser(IBUser.UUID, PropertiesIBUser);
		
		ModifiedInDesigner = False;
		String = Exporting.Find(PropertiesIBUser.UUID, "InfobaseUserID");
		
		If String <> Undefined Then
			String.Mapped = True;
			If String.FullName <> PropertiesIBUser.FullName Then
				ModifiedInDesigner = True;
			EndIf;
		EndIf;
		
		If ShowOnlyProcessedInDesignerItems
		   AND String <> Undefined
		   AND Not ModifiedInDesigner Then
			
			Continue;
		EndIf;
		
		NewRow = IBUsers.Add();
		NewRow.FullName                   = PropertiesIBUser.FullName;
		NewRow.Name                         = PropertiesIBUser.Name;
		NewRow.StandardAuthentication   = PropertiesIBUser.StandardAuthentication;
		NewRow.OSAuthentication            = PropertiesIBUser.OSAuthentication;
		NewRow.InfobaseUserID = PropertiesIBUser.UUID;
		NewRow.OSUser              = PropertiesIBUser.OSUser;
		NewRow.OpenIDAuthentication        = PropertiesIBUser.OpenIDAuthentication;
		
		If String = Undefined Then
			// There is no IB user in the catalog.
			NewRow.AddedInDesigner = True;
		Else
			NewRow.Ref                           = String.Ref;
			NewRow.MappedWithExternalUser = String.IsExternalUser;
			
			NewRow.ModifiedInDesigner = ModifiedInDesigner;
		EndIf;
		
	EndDo;
	
	Filter = New Structure("Mapped", False);
	Rows = Exporting.FindRows(Filter);
	For Each String IN Rows Do
		NewRow = IBUsers.Add();
		NewRow.FullName                        = String.FullName;
		NewRow.Ref                           = String.Ref;
		NewRow.MappedWithExternalUser = String.IsExternalUser;
		NewRow.DeletedInDesigner             = True;
		NonExistentInfobaseUserIDs.Add(String.InfobaseUserID);
	EndDo;
	
	Filter = New Structure("InfobaseUserID", CurrentInfobaseUserID);
	Rows = IBUsers.FindRows(Filter);
	If Rows.Count() > 0 Then
		Items.IBUsers.CurrentRow = Rows[0].GetID();
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteInfobaseUsers(InfobaseUserID, Cancel)
	
	ErrorDescription = "";
	If Not Users.DeleteInfobaseUsers(InfobaseUserID, ErrorDescription) Then
		CommonUseClientServer.MessageToUser(ErrorDescription, , , , Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenUserByRef()
	
	CurrentData = Items.IBUsers.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(CurrentData.Ref) Then
		OpenForm(
			?(CurrentData.MappedWithExternalUser,
				"Catalog.ExternalUsers.ObjectForm",
				"Catalog.Users.ObjectForm"),
			New Structure("Key", CurrentData.Ref));
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteCurrentIBUser(DeleteLine = False)
	
	ShowQueryBox(
		New NotifyDescription("DeleteCurrentIBUserEnd", ThisObject, DeleteLine),
		NStr("en='Delete infobase user?';ru='Удалить пользователя информационной базы?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteCurrentIBUserEnd(Response, DeleteLine) Export
	
	If Response = DialogReturnCode.Yes Then
		Cancel = False;
		DeleteInfobaseUsers(
			Items.IBUsers.CurrentData.InfobaseUserID, Cancel);
		
		If Not Cancel AND DeleteLine Then
			IBUsers.Delete(Items.IBUsers.CurrentData);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure MapIBUser(WithNew = False)
	
	If UserTypes.Count() > 1 Then
		UserTypes.ShowChooseItem(
			New NotifyDescription("MapIBUserForPointType", ThisObject, WithNew),
			NStr("en='Select data type';ru='Выбор типа данных'"),
			UserTypes[0]);
	Else
		MapIBUserForPointType(UserTypes[0], WithNew);
	EndIf;
	
EndProcedure

&AtClient
Procedure MapIBUserForPointType(ItemOfList, WithNew) Export
	
	If ItemOfList = Undefined Then
		Return;
	EndIf;
	
	CatalogName = ?(ItemOfList.Value = Type("CatalogRef.Users"), "Users", "ExternalUsers");
	
	If Not WithNew Then
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("NonExistentInfobaseUserIDs", NonExistentInfobaseUserIDs);
		
		OpenForm("Catalog." + CatalogName + ".ChoiceForm", FormParameters,,,,,
			New NotifyDescription("MapIBUserWithItem", ThisObject, CatalogName));
	Else
		MapIBUserWithItem("New", CatalogName);
	EndIf;
	
EndProcedure

&AtClient
Procedure MapIBUserWithItem(Item, CatalogName) Export
	
	If Not ValueIsFilled(Item) AND Item <> "New" Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	
	If Item <> "New" Then
		FormParameters.Insert("Key", Item);
	EndIf;
	
	FormParameters.Insert("InfobaseUserID",
		Items.IBUsers.CurrentData.InfobaseUserID);
	
	OpenForm("Catalog." + CatalogName + ".ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure CancelComplianceContinuation(Response, NotSpecified) Export
	
	If Response = "CancelMapping" Then
		CancelMappingAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure CancelMappingAtServer()
	
	CurrentRow = IBUsers.FindByID(
		Items.IBUsers.CurrentRow);
	
	Object = CurrentRow.Ref.GetObject();
	Object.InfobaseUserID = Undefined;
	Object.DataExchange.Load = True;
	Object.Write();
	
	FillInfobaseUsers();
	
EndProcedure

#EndRegion
