////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data exchange in the service model".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Handler of the application client session start.
// If the session is started for the offline workplace, then
// the user is notified about the necessity to synchronize
// data with the application in the Internet (if the corresponding flag is set).
//
Procedure OnStart(Parameters) Export
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If ClientWorkParameters.DataSeparationEnabled Then
		Return;
	EndIf;
	
	If ClientWorkParameters.ThisIsOfflineWorkplace Then
		ParameterName = "StandardSubsystems.OfferToSynchronizeDataWithApplicationOnTheInternetOnSessionExit";
		If ApplicationParameters[ParameterName] = Undefined Then
			ApplicationParameters.Insert(ParameterName, Undefined);
		EndIf;
		
		ApplicationParameters["StandardSubsystems.OfferToSynchronizeDataWithApplicationOnTheInternetOnSessionExit"] =
			ClientWorkParameters.SynchronizeDataWithApplicationInInternetOnExit;
		
		If ClientWorkParameters.SynchronizeDataWithApplicationInInternetOnWorkStart Then
			
			ShowUserNotification(NStr("en='OffLine work';ru='Автономная работа'"), "e1cib/app/DataProcessor.DataExchangeExecution",
				NStr("en='It is recommended to synchronize data with the online application.';ru='Рекомендуется синхронизировать данные с приложением в Интернете.'"), PictureLib.Information32);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// It is called on system shutdown to request
// a list of warnings displayed to a user.
//
// Parameters:
// see OnReceiveListOfEndWorkWarning.
//
Procedure OnExit(Warnings) Export
	
	OfflineWorkParameters = StandardSubsystemsClient.ClientWorkParametersOnComplete().OfflineWorkParameters;
	If ApplicationParameters["StandardSubsystems.OfferToSynchronizeDataWithApplicationOnTheInternetOnSessionExit"] = True
		AND OfflineWorkParameters.SynchronizationWithServiceHasNotBeenExecutedLongAgo Then
		
		WarningParameters = StandardSubsystemsClient.AlertOnEndWork();
		WarningParameters.ExtendedTooltip = NStr("en='In some cases data synchronization can take a long time:
		| - slow communication channel;
		| - large data volume;
		| - application update is avaliable in the Internet.';ru='В некоторых случаях синхронизация данных может занять длительное время:
		| - медленный канал связи;
		| - большой объем данных;
		| - доступно обновление приложения в Интернете.'");

		WarningParameters.FlagText = NStr("en='Synchronize data with the online application';ru='Синхронизировать данные с приложением в Интернете'");
		WarningParameters.Priority = 80;
		
		ActionIfMarked = WarningParameters.ActionIfMarked;
		ActionIfMarked.Form = "DataProcessor.DataExchangeExecution.Form.Form";
		
		FormParameters = OfflineWorkParameters.FormParametersDataExchange;
		FormParameters = CommonUseClientServer.CopyStructure(FormParameters);
		FormParameters.Insert("CompletingOfWorkSystem", True);
		ActionIfMarked.FormParameters = FormParameters;
		
		Warnings.Add(WarningParameters);
	EndIf;
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// Service events handlers of the SLL subsystems

// Defines the list of warnings to the user before the completion of the system work.
//
// Parameters:
//  Warnings - Array - you can add items of the
//                     Structure type to the array, for its properties, see  StandardSubsystemsClient.WarningOnWorkEnd.
//
Procedure OnGetListOfWarningsToCompleteJobs(Warnings) Export
	
	OnExit(Warnings);
	
EndProcedure

#EndRegion
