////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

Procedure ExportInfobaseUsers(Container) Export
	
	IBUsers= InfobaseUsers.GetUsers();
	IBUsers= SortInfobaseUserArrayBeforeExport(IBUsers);
	
	FileName = Container.CreateFile(DataExportImportService.Users());
	
	WriteStream = New XMLWriter();
	WriteStream.OpenFile(FileName);
	WriteStream.WriteXMLDeclaration();
	WriteStream.WriteStartElement("Data");
	
	For Each IBUser IN IBUsers Do
		
		XDTOFactory.WriteXML(WriteStream, SerializeInfobaseUser(IBUser));
		
	EndDo;
	
	WriteStream.WriteEndElement();
	WriteStream.Close();
	
EndProcedure

Procedure ImportInfobaseUsers(Container) Export
	
	FileName = Container.GetFileFromDirectory(DataExportImportService.Users());
	
	ReadStream = New XMLReader();
	ReadStream.OpenFile(FileName);
	ReadStream.MoveToContent();
	
	If ReadStream.NodeType <> XMLNodeType.StartElement
			Or ReadStream.Name <> "Data" Then
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = 'The XML reading error. Incorrect file format. The beginning of the item %1 is expected.'"),
			"Data"
		);
		
	EndIf;
	
	If Not ReadStream.Read() Then
		Raise NStr("en = 'The XML reading error. File completion is detected.'");
	EndIf;
	
	While ReadStream.NodeType = XMLNodeType.StartElement Do
		
		UserSerialization = XDTOFactory.ReadXML(ReadStream, XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "InfobaseUser"));
		
		IBUser = DeserializeInfobaseUser(UserSerialization);
		
		Cancel = False;
		DataExportImportServiceEvents.ExecuteActionsOnImportInfobaseUser(
			Container, UserSerialization, IBUser, Cancel);
		
		If Not Cancel Then
			
			IBUser.Write();
			
			DataExportImportServiceEvents.ExecuteActionsAfterImportInfobaseUser(
				Container, UserSerialization, IBUser);
			
		EndIf;
		
	EndDo;
	
	ReadStream.Close();
	
	DataExportImportServiceEvents.ExecuteActionsAfterImportInfobaseUsers(Container);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export

Function SortInfobaseUserArrayBeforeExport(Val SourceArray)
	
	VT = New ValueTable();
	VT.Columns.Add("User", New TypeDescription("InfobaseUser"));
	VT.Columns.Add("Administrator", New TypeDescription("Boolean"));
	
	For Each IBUser IN SourceArray Do
		
		VTRow = VT.Add();
		VTRow.User = IBUser;
		VTRow.Administrator = AccessRight("DataAdministration", Metadata, VTRow.User);
		
	EndDo;
	
	VT.Sort("Administrator Desc");
	
	Return VT.UnloadColumn("User");
	
EndFunction

Function SerializeInfobaseUser(Val User, Val StorePassword = False, Val StoreSeparation = False)
	
	InfobaseUserType = XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "InfobaseUser");
	UserRolesType = XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "UserRoles");
	
	XDTOUser = XDTOFactory.Create(InfobaseUserType);
	XDTOUser.OSAuthentication = User.OSAuthentication;
	XDTOUser.StandardAuthentication = User.StandardAuthentication;
	XDTOUser.CannotChangePassword = User.CannotChangePassword;
	XDTOUser.Name = User.Name;
	If User.DefaultInterface <> Undefined Then
		XDTOUser.DefaultInterface = User.DefaultInterface.Name;
	Else
		XDTOUser.DefaultInterface = "";
	EndIf;
	XDTOUser.PasswordIsSet = User.PasswordIsSet;
	XDTOUser.ShowInList = User.ShowInList;
	XDTOUser.DescriptionFull = User.DescriptionFull;
	XDTOUser.OSUser = User.OSUser;
	If StoreSeparation Then
		XDTOUser.DataSeparation = XDTOSerializer.WriteXDTO(User.DataSeparation);
	Else
		XDTOUser.DataSeparation = Undefined;
	EndIf;
	XDTOUser.RunMode = RunModeString(User.RunMode);
	XDTOUser.Roles = XDTOFactory.Create(UserRolesType);
	For Each Role IN User.Roles Do
		XDTOUser.Roles.Role.Add(Role.Name);
	EndDo;
	If StorePassword Then
		XDTOUser.StoredPasswordValue = User.StoredPasswordValue;
	Else
		XDTOUser.StoredPasswordValue = Undefined;
	EndIf;
	XDTOUser.UUID = User.UUID;
	If User.Language <> Undefined Then
		XDTOUser.Language = User.Language.Name;
	Else
		XDTOUser.Language = "";
	EndIf;
	
	Return XDTOUser;
	
EndFunction

Function RunModeString(Val RunMode)
	
	If RunMode = Undefined Then
		Return "";
	ElsIf RunMode = ClientRunMode.Auto Then
		Return "Auto";
	ElsIf RunMode = ClientRunMode.OrdinaryApplication Then
		Return "OrdinaryApplication";
	ElsIf RunMode = ClientRunMode.ManagedApplication Then
		Return "ManagedApplication";
	Else
		MessagePattern = NStr("en = 'Unknown launch mode of the client application %1'");
		MessageText = ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(MessagePattern, RunMode);
		Raise(MessageText);
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Import

Function DeserializeInfobaseUser(Val XDTOUser, Val RestorePassword = False, Val RestoreSeparation = False)
	
	User = InfobaseUsers.FindByUUID(XDTOUser.UUID);
	If User = Undefined Then
		User = InfobaseUsers.CreateUser();
	EndIf;
	
	User.OSAuthentication = XDTOUser.OSAuthentication;
	User.StandardAuthentication = XDTOUser.StandardAuthentication;
	User.CannotChangePassword = XDTOUser.CannotChangePassword;
	User.Name = XDTOUser.Name;
	If IsBlankString(XDTOUser.DefaultInterface) Then
		User.DefaultInterface = Undefined;
	Else
		User.DefaultInterface = Metadata.Interfaces.Find(XDTOUser.DefaultInterface);
	EndIf;
	User.ShowInList = XDTOUser.ShowInList;
	User.DescriptionFull = XDTOUser.DescriptionFull;
	User.OSUser = XDTOUser.OSUser;
	If RestoreSeparation Then
		If XDTOUser.DataSeparation = Undefined Then
			User.DataSeparation = New Structure;
		Else
			User.DataSeparation = XDTOSerializer.ReadXDTO(XDTOUser.DataSeparation);
		EndIf;
	Else
		User.DataSeparation = New Structure;
	EndIf;
	User.RunMode = ClientRunMode[XDTOUser.RunMode];
	User.Roles.Clear();
	For Each RoleName IN XDTOUser.Roles.Role Do
		Role = Metadata.Roles.Find(RoleName);
		If Role <> Undefined Then
			User.Roles.Add(Role);
		EndIf;
	EndDo;
	If RestorePassword Then
		User.StoredPasswordValue = XDTOUser.StoredPasswordValue;
	Else
		User.StoredPasswordValue = "";
	EndIf;
	If IsBlankString(XDTOUser.Language) Then
		User.Language = Undefined;
	Else
		User.Language = Metadata.Languages[XDTOUser.Language];
	EndIf;
	
	Return User;
	
EndFunction









