@echo off
title Online Bookstore Management System (PL/SQL)
echo ============================================================================
echo   ONLINE BOOKSTORE MANAGEMENT SYSTEM (Oracle PL/SQL Project)
echo ============================================================================
echo.
echo Starting Web Server on http://localhost:3000 ...
echo.
echo Web UI Storefront:   http://localhost:3000/index.html
echo Admin Dashboard:     http://localhost:3000/admin.html
echo PL/SQL Code Runner:  http://localhost:3000/plsql-runner.html
echo.
echo Press Ctrl+C at any time to terminate the server.
echo ============================================================================
node server/server.js
pause
