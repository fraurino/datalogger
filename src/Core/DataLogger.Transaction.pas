﻿{
  ********************************************************************************

  Github - https://github.com/dliocode/datalogger

  ********************************************************************************

  MIT License

  Copyright (c) 2022 Danilo Lucas

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

  ********************************************************************************
}

unit DataLogger.Transaction;

interface

uses
  DataLogger.Types,
  System.Generics.Collections;

type
  TDataLoggerTransaction = class
  public
    InTransaction: Boolean;
    ListItemTransaction: TDataLoggerListItemTransaction;

    destructor Destroy; override;
  end;

  TDataLoggerListTransaction = TObjectDictionary<string, TDataLoggerTransaction>;

implementation

{ TDataLoggerTransaction }

destructor TDataLoggerTransaction.Destroy;
begin
  if Assigned(ListItemTransaction) then
  begin
    ListItemTransaction.Free;
    ListItemTransaction := nil;
  end;

  inherited;
end;

end.
