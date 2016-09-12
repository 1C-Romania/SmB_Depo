
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	RunMode = Constants.InfobaseUsageMode.Get();
	If RunMode = Enums.InfobaseUsageModes.Demo Then
		Raise(NStr("en='New users adding is not available in the demo mode';ru='В демонстрационном режиме не доступно добавление новых пользователей'"));
	EndIf;
	
	// Form is unavailable until the preparation is not finished.
	Enabled = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ServiceUserPassword = Undefined Then
		Cancel = True;
		AttachIdleHandler("RequestPasswordForAuthenticationInService", 0.1, True);
	Else
		PrepareForm();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CheckAll(Command)
	
	For Each TableRow IN ServiceUsers Do
		If TableRow.Access Then
			Continue;
		EndIf;
		TableRow.Add = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	For Each TableRow IN ServiceUsers Do
		TableRow.Add = False;
	EndDo;
	
EndProcedure

&AtClient
Procedure AddSelectedUsers(Command)
	
	AddSelectedUsersAtServer();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersAdd.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ServiceUsers.Access");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("Enabled", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersAdd.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersFullName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUserAccess.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ServiceUsers.Access");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.InaccessibleDataColor);

EndProcedure

&AtClient
Procedure RequestPasswordForAuthenticationInService()
	
	StandardSubsystemsClient.WhenPromptedForPasswordForAuthenticationToService(
		New NotifyDescription("AtOpenContinuation", ThisObject));
	
EndProcedure

&AtClient
Procedure AtOpenContinuation(NewServiceUserPassword, NotSpecified) Export
	
	If NewServiceUserPassword <> Undefined Then
		ServiceUserPassword = NewServiceUserPassword;
		Open();
	EndIf;
	
EndProcedure

&AtServer
Procedure PrepareForm()
	
	UsersServiceSaaS.GetActionsWithServiceUser(
		Catalogs.Users.EmptyRef());
		
	UsersTable = UsersServiceSaaS.GetServiceUsers(
		ServiceUserPassword);
		
	For Each UserInfo IN UsersTable Do
		UserRow = ServiceUsers.Add();
		FillPropertyValues(UserRow, UserInfo);
	EndDo;
	
	Enabled = True;
	
EndProcedure

&AtServer
Procedure AddSelectedUsersAtServer()
	
	SetPrivilegedMode(True);
	
	Counter = 0;
	LineCount = ServiceUsers.Count();
	For Counter = 1 To LineCount Do
		TableRow = ServiceUsers[LineCount - Counter];
		If Not TableRow.Add Then
			Continue;
		EndIf;
		
		UsersServiceSaaS.GiveAccessToServiceUser(
			TableRow.ID, ServiceUserPassword);
		
		ServiceUsers.Delete(TableRow);
	EndDo;
	
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
