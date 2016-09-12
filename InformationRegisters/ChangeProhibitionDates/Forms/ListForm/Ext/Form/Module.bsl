
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Command setting
	SectionsProperties = ChangeProhibitionDatesServiceReUse.SectionsProperties();
	Items.DataImportProhibitionDateForm.Visible = SectionsProperties.UseProhibitionDatesOfDataImport;
	
	// Order setting
	Order = List.SettingsComposer.Settings.Order;
	Order.UserSettingID = "DefaultOrder";
	
	Order.Items.Clear();
	
	OrderingItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderingItem.Field = New DataCompositionField(Items.ListUser.Name);
	OrderingItem.OrderType = DataCompositionSortDirection.Asc;
	OrderingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderingItem.Use = True;
	
	OrderingItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderingItem.Field = New DataCompositionField(Items.ListSection.Name);
	OrderingItem.OrderType = DataCompositionSortDirection.Asc;
	OrderingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderingItem.Use = True;
	
	OrderingItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderingItem.Field = New DataCompositionField(Items.ListObject.Name);
	OrderingItem.OrderType = DataCompositionSortDirection.Asc;
	OrderingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderingItem.Use = True;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure DataChangeProhibitionDates(Command)
	
	OpenForm("InformationRegister.ChangeProhibitionDates.Form.ChangeProhibitionDates");
	
EndProcedure

&AtClient
Procedure DataImportingProhibitionDates(Command)
	
	FormParameters = New Structure("DataImportingProhibitionDates", True);
	OpenForm("InformationRegister.ChangeProhibitionDates.Form.ChangeProhibitionDates", FormParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	For Each UserType IN Metadata.InformationRegisters.ChangeProhibitionDates.Dimensions.User.Type.Types() Do
		MetadataObject = Metadata.FindByType(UserType);
		If Not Metadata.ExchangePlans.Contains(MetadataObject) Then
			Continue;
		EndIf;
		
		IssueValue(CommonUse.ObjectManagerByFullName(MetadataObject.FullName()).EmptyRef(),
			MetadataObject.Presentation() + ": " + NStr("en='<All infobases>';ru='<Все информационные базы>'"));
	EndDo;
	
	IssueValue(Undefined,
		NStr("en='Undefined';ru='Неопределено'"));
	
	IssueValue(Catalogs.Users.EmptyRef(),
		NStr("en='Empty user';ru='Пустой пользователь'"));
	
	IssueValue(Catalogs.UsersGroups.EmptyRef(),
		NStr("en='Empty group of users';ru='Пустая группа пользователей'"));
	
	IssueValue(Catalogs.ExternalUsers.EmptyRef(),
		NStr("en='Empty external user';ru='Пустой внешний пользователь'"));
	
	IssueValue(Catalogs.ExternalUsersGroups.EmptyRef(),
		NStr("en='Empty group of external users';ru='Пустая группа внешних пользователей'"));
	
	IssueValue(Enums.ProhibitionDatesPurposeKinds.ForAllUsers,
		"<" + Enums.ProhibitionDatesPurposeKinds.ForAllUsers + ">");
	
	IssueValue(Enums.ProhibitionDatesPurposeKinds.ForAllDatabases,
		"<" + Enums.ProhibitionDatesPurposeKinds.ForAllDatabases + ">");
	
EndProcedure

&AtServer
Procedure IssueValue(Value, Text)
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ListUser.Name);
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("List.User");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = Value;
	
	Item.Appearance.SetParameterValue("Text", Text);
	
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
