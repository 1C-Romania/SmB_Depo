#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var ControlRequired;
Var DataForWriting;
Var DataIsPrepared;

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	// The DataExchange.Load property valueThere is no import for the
	// reason that the restrictions imposed by this code should not be
	// bypassed by setting this property to True (on the side of the code which attempts to write to this register).
	//
	// This register should not be involved into any exchanges or data export / import
	// operations when data distribution by areas is enabled.
	
	If DataIsPrepared Then
		ThisObject.Load(DataForWriting);
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	// The DataExchange.Load property valueThere is no import for the
	// reason that the restrictions imposed by this code should not be
	// bypassed by setting this property to True (on the side of the code which attempts to write to this register).
	//
	// This register should not be involved into any exchanges or data export / import
	// operations when data distribution by areas is enabled.
	
	If ControlRequired Then
		
		For Each Record IN ThisObject Do
			
			ControlRows = DataForWriting.FindRows(
				New Structure("Identifier, DataType", Record.ID, Record.DataType));
			
			If ControlRows.Count() <> 1 Then
				VerificationError();
			Else
				
				ControlString = ControlRows.Get(0);
				
				CurrentData = CommonUse.ValueToXMLString(Record.Data.Get());
				ControlData = CommonUse.ValueToXMLString(ControlString.Data.Get());
				
				If CurrentData <> ControlData Then
					VerificationError();
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure PrepareDataForWrite() Export
	
	ReceivingParameters = Undefined;
	If Not AdditionalProperties.Property("ReceivingParameters", ReceivingParameters) Then
		Raise NStr("en='Data receipt parameters are not specified';ru='Не определены параметры получения данных'");
	EndIf;
	
	DataForWriting = ThisObject.Unload();
	
	For Each String IN DataForWriting Do
		
		Data = CommonUse.PrepareDataCacheVersions(String.DataType, ReceivingParameters);
		String.Data = New ValueStorage(Data);
		
	EndDo;
	
	DataIsPrepared = True;
	
EndProcedure

Procedure VerificationError()
	
	Raise NStr("en='Inadmissible resource update Data of information
		|register record ProgramInterfaceCache inside record transaction from session with enabled division!';ru='Недопустимое изменение ресурса Данные записи регистра сведений КэшПрограммныхИнтерфейсов
		|внутри транзакции записи из сеанса с включенным разделением!'");
	
EndProcedure

DataForWriting = New ValueTable();
ControlRequired = CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData();
DataIsPrepared = False;

#EndRegion

#EndIf
