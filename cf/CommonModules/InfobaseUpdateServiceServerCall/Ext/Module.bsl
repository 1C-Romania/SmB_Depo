////////////////////////////////////////////////////////////////////////////////
// IB version update subsystem
// Server procedures and functions of
// the infobase update on configuration version change.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// See description of this same function in the InfobaseUpdateService module.
Function RunInfobaseUpdate(ExceptWhenImpossibleLockIB = True,
	ClientApplicationsOnStart = False, Restart = False) Export
	
	UpdateParameters = InfobaseUpdateService.UpdateParameters();
	UpdateParameters.ExceptWhenImpossibleLockIB = ExceptWhenImpossibleLockIB;
	UpdateParameters.ClientApplicationsOnStart = ClientApplicationsOnStart;
	UpdateParameters.Restart = Restart;
	
	Result = InfobaseUpdateService.RunInfobaseUpdate(UpdateParameters);
	
	Restart = UpdateParameters.Restart;
	Return Result;
	
EndFunction

// Unlocks the file infobase.
Procedure RemoveLockFileBase() Export
	
	InfobaseUpdateService.WhenRemovingLockFileBase();
	
EndProcedure

// Writes duration of the main update cycle to the constant.
//
Procedure WriteExecutionTimeUpdate(UpdateBeginTime, UpdateEndTime) Export
	
	If CommonUseReUse.DataSeparationEnabled() AND Not CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	DataAboutUpdate = InfobaseUpdateService.DataOnUpdatingInformationBase();
	DataAboutUpdate.UpdateBeginTime = UpdateBeginTime;
	DataAboutUpdate.UpdateEndTime = UpdateEndTime;
	
	TimeInSeconds = UpdateEndTime - UpdateBeginTime;
	
	Hours = Int(TimeInSeconds/3600);
	Minutes = Int((TimeInSeconds - Hours * 3600) / 60);
	Seconds = TimeInSeconds - Hours * 3600 - Minutes * 60;
	
	DurationHours = ?(Hours = 0, "",
		StringFunctionsClientServer.SubstituteParametersInString(NStr("en='%1 hour';ru='%1 час'"), Hours));
	DurationMinutes = ?(Minutes = 0, "",
		StringFunctionsClientServer.SubstituteParametersInString(NStr("en='%1 min';ru='%1 мин'"), Minutes));
	DurationSeconds = ?(Seconds = 0, "",
		StringFunctionsClientServer.SubstituteParametersInString(NStr("en='%1 sec';ru='%1 сек'"), Seconds));
	DurationOfUpdate = DurationHours + " " + DurationMinutes + " " + DurationSeconds;
	DataAboutUpdate.DurationOfUpdate = TrimAll(DurationOfUpdate);
	
	InfobaseUpdateService.WriteDataOnUpdatingInformationBase(DataAboutUpdate);
	
EndProcedure

#EndRegion
