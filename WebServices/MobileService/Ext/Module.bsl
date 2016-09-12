
// data getting
// operation receives the change package intended for this node
//
// Parameters:
//  MobileComputerCode	- node code with which exchange is executing
//
// Returns:
//  ValueStorage in which exchange package is placed
//
Function GetExchangePackage(CodeMobileComputer, MessageNumberExchange, JobID)
	
	SetPrivilegedMode(True);
	
	ExchangeNode = ExchangePlans.MobileApplication.FindByCode(CodeMobileComputer); 
	
	If ExchangeNode.IsEmpty() Then
		Raise(NStr("en='The unknown device - ';ru='Неизвестное устройство - '") + CodeMobileComputer);
	EndIf;
	
	Return MobileApplicationExchangeGeneral.GetExchangeMessage(ExchangeNode, MessageNumberExchange, JobID);
	
EndFunction

// Data record
// operation writes change package received from this node
//
// Parameters:
//  MobileComputerCode	- node code
//  with which exchange MobileApplicationData is executing - ValueStorage in which exchange package is placed
//
// Returns:
//  no
//
Function AcceptExchangePackage(DataMobileApplications, CodeMobileComputer, DescriptionOfMobileComputer, SentNo, ReceivedNo, PeriodExportings)
	
	AnswerStructure = New Structure("JobID, NewExchange", Undefined, False);
	
	User = Users.AuthorizedUser();
	
	CheckUserRights(User);
	
	SetPrivilegedMode(True);
	
	PeriodApplicationInstalledInMobileExportings = SmallBusinessReUse.GetValueByDefaultUser(
		User,
		"MobileApplicationExportingsPeriod"
	);

	If PeriodExportings = "In last month" Then
		MobileApplicationExportingsPeriod = Enums.ExportPeriodsInMobileApplication.InLastMonth;
	ElsIf PeriodExportings = "In last week" Then
		MobileApplicationExportingsPeriod = Enums.ExportPeriodsInMobileApplication.InLastWeek;
	Else
		MobileApplicationExportingsPeriod = Enums.ExportPeriodsInMobileApplication.InLastDay;
	EndIf;
	
	If PeriodApplicationInstalledInMobileExportings <> MobileApplicationExportingsPeriod Then
		SmallBusinessServer.SetUserSetting(MobileApplicationExportingsPeriod, "MobileApplicationExportingsPeriod")
	EndIf;
	
	If Not CommonUse.FileInfobase() Then
		
		FilterStructure = New Structure("Description", CodeMobileComputer);
		TasksArray = BackgroundJobs.GetBackgroundJobs(FilterStructure);
		IsActiveTaskSch = False;
		For Each BackgroundJob IN TasksArray Do
			If BackgroundJob.State = BackgroundJobState.Active Then
				BackgroundJob.Cancel();
			EndIf;
		EndDo;
	EndIf;
	
	ExchangeNode = ExchangePlans.MobileApplication.ThisNode().GetObject();
	If Not ValueIsFilled(ExchangeNode.Code) Then
		
		ExchangeNode.DataExchange.Load = True;
		ExchangeNode.Code = "001";
		ExchangeNode.Description = "Central";
		ExchangeNode.Write();
		
	EndIf;
	
	NeedNodeInitialization = False;
	
	ExchangeNode = ExchangePlans.MobileApplication.FindByCode(CodeMobileComputer); 
	If ExchangeNode.IsEmpty() Then
		
		NewNode = ExchangePlans.MobileApplication.CreateNode();
		NewNode.Code = CodeMobileComputer;
		NewNode.Description = DescriptionOfMobileComputer;
		NewNode.SentNo = SentNo;
		NewNode.ReceivedNo = ReceivedNo;
		NewNode.Write();
		
		ExchangeNode = NewNode.Ref;
		NeedNodeInitialization = True;
	Else
		
		If ExchangeNode.DeletionMark OR
			ExchangeNode.Description <> DescriptionOfMobileComputer Then
			
			Node = ExchangeNode.GetObject();
			Node.DeletionMark = False;
			Node.Description = DescriptionOfMobileComputer;
			Node.Write();
			
		EndIf;
		
		If ExchangeNode.SentNo = 0
			OR ExchangeNode.ReceivedNo = 0
			OR ExchangeNode.SentNo < ReceivedNo
			OR ExchangeNode.ReceivedNo <> SentNo Then
			
			Node = ExchangeNode.GetObject();
			Node.SentNo = ReceivedNo;
			Node.ReceivedNo = SentNo;
			Node.Write();
			
			NeedNodeInitialization = True;
			
		EndIf;
		
	EndIf;
		
	MobileApplicationExchangeGeneral.AcceptExchangePackage(ExchangeNode, DataMobileApplications);
	
	MobileApplicationExchangeGeneral.RunExchangeMessagesQueueFormation(ExchangeNode, CodeMobileComputer, ReceivedNo, NeedNodeInitialization, AnswerStructure.JobID);
	AnswerStructure.NewExchange = NeedNodeInitialization;
	
	Return New ValueStorage(AnswerStructure, New Deflation(9));
	
EndFunction

Procedure CheckUserRights(User = Undefined)
	
	If User = Undefined Then
		User = Users.AuthorizedUser();
	EndIf;
	
	If Not IsInRole(Metadata.Roles.FullRights)
	   AND Not(IsInRole(Metadata.Roles.AddChangeSalesSubsystem) // Profile Basic rights.
		  AND IsInRole(Metadata.Roles.AddChangePettyCashSubsystem)
		  AND IsInRole(Metadata.Roles.AddChangeBankSubsystem)) Then // Profile Funds.
		
		Raise(
			NStr("en='User ""';ru='Пользователь ""'")
		  + User
		  + NStr("en='"" there aren not rights on data synchronization with mobile application 1C:Small Business. It is required to add the Basic rights and Funds access rights profiles.';ru='"" нет прав на синхронизацию данных с мобильным приложением 1С:Управление небольшой фирмой. Необходимо включить профили прав доступа Базовые права и Деньги.'")
		);
		
	EndIf;
	
EndProcedure

// Operation
// of the exchange start checks that the necessary node is added to the plan and correctly initialized
//
// Parameters:
//  MobileComputerCode	– unchangeable unique identifier of this node, it is
//  used as a exchange plan node code MobileComputerDescription - readable representation of this node, it is not necessarily, changeable, it
//  is used as the exchange plan node description NumberSent - number of the last sent package is intended to restore exchange
//  if the node was deleted NumberAccepted - number of the last accepted package is intended to restore exchange if the node was deleted
//
// Returns:
//  no
//
Function StartExchange(CodeMobileComputer, DescriptionOfMobileComputer, SentNo, ReceivedNo, PeriodExportings)
	
	User = Users.AuthorizedUser();
	
	CheckUserRights(User);
	
	SetPrivilegedMode(True);
	
	PeriodApplicationInstalledInMobileExportings = SmallBusinessReUse.GetValueByDefaultUser(
		User,
		"MobileApplicationExportingsPeriod"
	);

	If PeriodExportings = "In last month" Then
		MobileApplicationExportingsPeriod = Enums.ExportPeriodsInMobileApplication.InLastMonth;
	ElsIf PeriodExportings = "In last week" Then
		MobileApplicationExportingsPeriod = Enums.ExportPeriodsInMobileApplication.InLastWeek;
	Else
		MobileApplicationExportingsPeriod = Enums.ExportPeriodsInMobileApplication.InLastDay;
	EndIf;
	
	If PeriodApplicationInstalledInMobileExportings <> MobileApplicationExportingsPeriod Then
		SmallBusinessServer.SetUserSetting(MobileApplicationExportingsPeriod, "MobileApplicationExportingsPeriod")
	EndIf;
	
	ExchangeNode = ExchangePlans.MobileApplication.ThisNode().GetObject();
	If Not ValueIsFilled(ExchangeNode.Code) Then
		
		ExchangeNode.DataExchange.Load = True;
		ExchangeNode.Code = "001";
		ExchangeNode.Description = "Central";
		ExchangeNode.Write();
		
	EndIf;
	
	ExchangeNode = ExchangePlans.MobileApplication.FindByCode(CodeMobileComputer); 
	If ExchangeNode.IsEmpty() Then
		
		NewNode = ExchangePlans.MobileApplication.CreateNode();
		NewNode.Code = CodeMobileComputer;
		NewNode.Description = DescriptionOfMobileComputer;
		NewNode.SentNo = SentNo;
		NewNode.ReceivedNo = ReceivedNo;
		NewNode.Write();
		ExchangeMobileApplicationOverridable.RecordChangesData(NewNode.Ref);
		ExchangeNode = NewNode.Ref;
		
	Else
		
		If ExchangeNode.DeletionMark OR
			ExchangeNode.Description <> DescriptionOfMobileComputer Then
			
			Node = ExchangeNode.GetObject();
			Node.DeletionMark = False;
			Node.Description = DescriptionOfMobileComputer;
			Node.Write();
			
		EndIf;
		
		If ExchangeNode.SentNo <> SentNo OR
			 ExchangeNode.ReceivedNo <> ReceivedNo Then
			
			Node = ExchangeNode.GetObject();
			Node.SentNo = SentNo;
			Node.ReceivedNo = ReceivedNo;
			Node.Write();
			
			ExchangePlans.DeleteChangeRecords(ExchangeNode);
			ExchangeMobileApplicationOverridable.RecordChangesData(ExchangeNode);
			
		EndIf;
		
	EndIf;
	
EndFunction

// Data getting operation receives the change package
// intended for this node
//
// Parameters:
//  MobileComputerCode	- node code with which exchange is executing
//
// Returns:
//  ValueStorage in which exchange package is placed
//
Function GetData(CodeMobileComputer)
	
	SetPrivilegedMode(True);
	
	ExchangeNode = ExchangePlans.MobileApplication.FindByCode(CodeMobileComputer); 
	
	If ExchangeNode.IsEmpty() Then
		Raise(NStr("en='The unknown device - ';ru='Неизвестное устройство - '") + CodeMobileComputer);
	EndIf;
	
	Return MobileApplicationExchangeGeneral.GeneratePackageExchange(ExchangeNode);
	
EndFunction

// Data record
// operation writes change package received from this node
//
// Parameters:
//  MobileComputerCode	   - node code with which exchange is executing 
//  MobileApplicationData  - ValueStorage in which exchange package is placed
//
// Returns:
//  no
//
Function WriteData(CodeMobileComputer, DataMobileApplications)
	
	SetPrivilegedMode(True);
	
	ExchangeNode = ExchangePlans.MobileApplication.FindByCode(CodeMobileComputer); 
	
	If ExchangeNode.IsEmpty() Then
		Raise(NStr("en='The unknown device - ';ru='Неизвестное устройство - '") + CodeMobileComputer);
	EndIf;
	
	MobileApplicationExchangeGeneral.AcceptExchangePackage(ExchangeNode, DataMobileApplications, True);
	
EndFunction
