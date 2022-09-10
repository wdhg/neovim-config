local status, grammar_guard = pcall(require, 'grammar-guard')

if (not status) then
  return
end

grammar_guard.init()
