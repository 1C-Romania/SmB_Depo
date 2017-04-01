#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then


// Updates the record in the register by the passed structure values
//
Procedure UpdateRecord(RecordStructure) Export
	
	DataExchangeServer.UpdateRecordToInformationRegister(RecordStructure, "DataAreasTransportExchangeSettings");
	
EndProcedure

//

Function TransportSettings(Val CorrespondentEndPoint) Export
	
	QueryText =
	"SELECT
	|	DataAreasTransportExchangeSettings.FILEInformationExchangeDirectory,
	|	DataAreasTransportExchangeSettings.FILECompressOutgoingMessageFile,
	|	DataAreasTransportExchangeSettings.FTPCompressOutgoingMessageFile,
	|	DataAreasTransportExchangeSettings.FTPConnectionMaximumValidMessageSize,
	|	DataAreasTransportExchangeSettings.FTPConnectionPassword,
	|	DataAreasTransportExchangeSettings.FTPConnectionPassiveConnection,
	|	DataAreasTransportExchangeSettings.FTPConnectionUser,
	|	DataAreasTransportExchangeSettings.FTPConnectionPort,
	|	DataAreasTransportExchangeSettings.FTPConnectionPath,
	|	DataAreasTransportExchangeSettings.ExchangeMessageTransportKindByDefault,
	|	DataAreasTransportExchangeSettings.ExchangeMessageArchivePassword
	|FROM
	|	InformationRegister.DataAreasTransportExchangeSettings AS DataAreasTransportExchangeSettings
	|WHERE
	|	DataAreasTransportExchangeSettings.CorrespondentEndPoint = &CorrespondentEndPoint";
	
	Query = New Query;
	Query.SetParameter("CorrespondentEndPoint", CorrespondentEndPoint);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Settings for the connection to the end point %1 have not been specified.';ru='Не заданы настройки подключения для конечной точки %1.'"),
			String(CorrespondentEndPoint));
	EndIf;
	
	Result = DataExchangeServer.QueryResultIntoStructure(QueryResult);
	
	If Result.ExchangeMessageTransportKindByDefault = Enums.ExchangeMessagesTransportKinds.FTP Then
		
		FTPParameters = DataExchangeServer.FTPServerNameAndPath(Result.FTPConnectionPath);
		
		Result.Insert("FTPServer", FTPParameters.Server);
		Result.Insert("FTPPath",   FTPParameters.Path);
	Else
		Result.Insert("FTPServer", "");
		Result.Insert("FTPPath",   "");
	EndIf;
	
	DataExchangeServer.AddTransactionItemCountToTransportSettings(Result);
	
	Return Result;
	
EndFunction

#EndIf